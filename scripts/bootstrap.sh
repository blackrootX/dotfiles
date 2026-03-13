#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BREWFILE="${REPO_ROOT}/Brewfile"
CONFIGS_DIR="${REPO_ROOT}/configs"
REPO_ZPROFILE="${CONFIGS_DIR}/zsh/.zprofile"
REPO_ZSHRC="${CONFIGS_DIR}/zsh/.zshrc"
REPO_ZSH_PLUGINS="${CONFIGS_DIR}/zsh/.zsh_plugins.txt"
REPO_STARSHIP_CONFIG="${CONFIGS_DIR}/starship/starship.toml"
REPO_GHOSTTY_DIR="${CONFIGS_DIR}/ghostty"
REPO_MISE_CONFIG="${CONFIGS_DIR}/mise/mise.toml"
LOCAL_ZPROFILE="${HOME}/.zprofile"
LOCAL_ZSHRC="${HOME}/.zshrc"
LOCAL_ZSH_PLUGINS="${HOME}/.zsh_plugins.txt"
LOCAL_STARSHIP_CONFIG="${HOME}/.config/starship.toml"
LOCAL_GHOSTTY_DIR="${HOME}/.config/ghostty"
LOCAL_MISE_CONFIG="${HOME}/.config/mise/config.toml"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"
HOMEBREW_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

log() {
  printf '[bootstrap] %s\n' "$1"
}

refresh_sudo() {
  if [[ ! -t 0 ]]; then
    log "Skipping sudo credential refresh because this shell is non-interactive"
    return
  fi

  log "Refreshing sudo credentials"
  sudo -v
}

require_macos() {
  if [[ "$(uname -s)" != "Darwin" ]]; then
    printf 'This script supports macOS only.\n' >&2
    exit 1
  fi
}

brew_prefix_for_arch() {
  case "$(uname -m)" in
    arm64) printf '/opt/homebrew' ;;
    x86_64) printf '/usr/local' ;;
    *)
      printf 'Unsupported macOS architecture: %s\n' "$(uname -m)" >&2
      exit 1
      ;;
  esac
}

ensure_brew_in_path() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  local prefix
  prefix="$(brew_prefix_for_arch)"

  if [[ -x "${prefix}/bin/brew" ]]; then
    eval "$("${prefix}/bin/brew" shellenv)"
    return
  fi

  printf 'Homebrew is installed but could not be initialized.\n' >&2
  exit 1
}

install_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    log "Homebrew already installed"
    return
  fi

  local installer_script
  installer_script="$(mktemp)"

  log "Installing Homebrew"
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_INSTALL_FROM_API=1
  unset HOMEBREW_BREW_GIT_REMOTE
  unset HOMEBREW_CORE_GIT_REMOTE

  curl -fsSL "${HOMEBREW_INSTALL_SCRIPT_URL}" -o "${installer_script}"
  NONINTERACTIVE=1 /bin/bash "${installer_script}"
  rm -f "${installer_script}"
  ensure_brew_in_path
}

configure_homebrew_china_mirror() {
  local brew_repo core_repo cask_repo

  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_TUNA_GIT_MIRROR}/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_TUNA_GIT_MIRROR}/homebrew-core.git"
  export HOMEBREW_INSTALL_FROM_API=1

  brew_repo="$(brew --repo)"
  core_repo="$(brew --repo homebrew/core)"

  if [[ -d "${brew_repo}/.git" ]]; then
    log "Configuring Homebrew brew remote to Tsinghua mirror"
    git -C "${brew_repo}" remote set-url origin "${HOMEBREW_BREW_GIT_REMOTE}"
  fi

  if [[ -d "${core_repo}/.git" ]]; then
    log "Configuring Homebrew core remote to Tsinghua mirror"
    git -C "${core_repo}" remote set-url origin "${HOMEBREW_CORE_GIT_REMOTE}"
  fi

  if cask_repo="$(brew --repo homebrew/cask 2>/dev/null)"; then
    if [[ -d "${cask_repo}/.git" ]]; then
      log "Configuring Homebrew cask remote to Tsinghua mirror"
      git -C "${cask_repo}" remote set-url origin "${HOMEBREW_TUNA_GIT_MIRROR}/homebrew-cask.git"
    fi
  fi
}

link_managed_file() {
  local source_path="$1"
  local target_path="$2"
  local label="$3"

  mkdir -p "$(dirname "${source_path}")" "$(dirname "${target_path}")"

  if [[ ! -e "${source_path}" ]]; then
    printf 'Managed %s not found: %s\n' "${label}" "${source_path}" >&2
    exit 1
  fi

  if [[ -L "${target_path}" ]]; then
    local current_target
    current_target="$(readlink "${target_path}")"

    if [[ "${current_target}" == "${source_path}" ]]; then
      log "Local ${label} already points to repo-managed file"
      return
    fi
  fi

  if [[ -e "${target_path}" || -L "${target_path}" ]]; then
    log "Replacing existing ${label}"
    rm -rf "${target_path}"
  fi

  log "Linking ${target_path} to repo-managed ${label}"
  ln -s "${source_path}" "${target_path}"
}

link_zprofile() {
  link_managed_file "${REPO_ZPROFILE}" "${LOCAL_ZPROFILE}" ".zprofile"
}

link_zshrc() {
  link_managed_file "${REPO_ZSHRC}" "${LOCAL_ZSHRC}" ".zshrc"
}

link_zsh_plugins() {
  link_managed_file \
    "${REPO_ZSH_PLUGINS}" \
    "${LOCAL_ZSH_PLUGINS}" \
    ".zsh_plugins.txt"
}

link_starship_config() {
  link_managed_file \
    "${REPO_STARSHIP_CONFIG}" \
    "${LOCAL_STARSHIP_CONFIG}" \
    "starship config"
}

link_ghostty_config() {
  link_managed_file \
    "${REPO_GHOSTTY_DIR}" \
    "${LOCAL_GHOSTTY_DIR}" \
    "Ghostty config"
}

link_mise_config() {
  link_managed_file \
    "${REPO_MISE_CONFIG}" \
    "${LOCAL_MISE_CONFIG}" \
    "mise config"
}

install_brew_bundle() {
  if [[ ! -f "${BREWFILE}" ]]; then
    printf 'Brewfile not found: %s\n' "${BREWFILE}" >&2
    exit 1
  fi

  local -a taps=()
  local -a formulae=()
  local -a casks=()
  local line

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*tap[[:space:]]+\"([^\"]+)\" ]]; then
      taps+=("${BASH_REMATCH[1]}")
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*brew[[:space:]]+\"([^\"]+)\" ]]; then
      formulae+=("${BASH_REMATCH[1]}")
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
      casks+=("${BASH_REMATCH[1]}")
    fi
  done < "${BREWFILE}"

  local idx
  local total
  local item

  total="${#taps[@]}"
  for (( idx=0; idx<total; idx++ )); do
    item="${taps[idx]}"
    log "Tap [$((idx + 1))/${total}]: ${item}"
    if brew tap | grep -qx "${item}"; then
      log "Tap already installed: ${item}"
    else
      brew tap "${item}"
    fi
  done

  total="${#formulae[@]}"
  for (( idx=0; idx<total; idx++ )); do
    item="${formulae[idx]}"
    log "Formula [$((idx + 1))/${total}]: ${item}"
    if brew list --formula "${item}" >/dev/null 2>&1; then
      log "Formula already installed: ${item}"
    else
      brew install --formula --verbose "${item}"
    fi
  done

  total="${#casks[@]}"
  for (( idx=0; idx<total; idx++ )); do
    item="${casks[idx]}"
    log "Cask [$((idx + 1))/${total}]: ${item}"
    if brew list --cask "${item}" >/dev/null 2>&1; then
      log "Cask already installed: ${item}"
    else
      brew install --cask --verbose "${item}"
    fi
  done
}

run_1password_checkpoint() {
  if ! command -v op >/dev/null 2>&1; then
    log "1Password CLI is not installed, skipping 1Password checkpoint"
    return
  fi

  if op whoami >/dev/null 2>&1; then
    log "1Password CLI is already signed in"
    return
  fi

  if [[ ! -t 0 ]]; then
    log "Skipping 1Password sign-in checkpoint because this shell is non-interactive"
    return
  fi

  local choice
  printf '\n'
  printf '1Password CLI is installed but not signed in yet.\n'
  printf 'This is the manual checkpoint for a new Mac before any secret-backed setup.\n'
  printf 'Run 1Password CLI sign-in now? [y/N]: '
  IFS= read -r choice

  if [[ ! "${choice}" =~ ^[Yy]$ ]]; then
    log "Skipping 1Password sign-in checkpoint by user request"
    return
  fi

  log "Starting 1Password CLI sign-in"
  if ! eval "$(op signin)"; then
    printf '1Password CLI sign-in did not complete successfully.\n' >&2
    printf 'Rerun bootstrap later or sign in manually with `eval $(op signin)`.\n' >&2
    exit 1
  fi

  if ! op whoami >/dev/null 2>&1; then
    printf '1Password CLI sign-in did not leave an active session.\n' >&2
    printf 'Rerun bootstrap later or sign in manually with `eval $(op signin)`.\n' >&2
    exit 1
  fi

  log "1Password CLI sign-in complete"
}

install_mise_node_tools() {
  if ! command -v mise >/dev/null 2>&1; then
    printf 'mise is required but was not found after Brewfile install.\n' >&2
    exit 1
  fi

  if [[ ! -f "${REPO_MISE_CONFIG}" ]]; then
    printf 'mise config not found: %s\n' "${REPO_MISE_CONFIG}" >&2
    exit 1
  fi

  log "Trusting repo-managed mise config"
  mise trust "${REPO_MISE_CONFIG}"

  log "Installing repo-managed mise tools from global config"
  if mise install -C "${CONFIGS_DIR}/mise" -y; then
    return
  fi

  log "Retrying mise install with source builds enabled"
  MISE_ALL_COMPILE=1 mise install -C "${CONFIGS_DIR}/mise" -y
}

main() {
  require_macos
  refresh_sudo
  install_homebrew
  ensure_brew_in_path
  configure_homebrew_china_mirror
  link_zprofile
  link_zshrc
  link_zsh_plugins
  link_starship_config
  link_ghostty_config
  link_mise_config
  install_brew_bundle
  run_1password_checkpoint
  install_mise_node_tools
  log "Bootstrap complete"
}

main "$@"

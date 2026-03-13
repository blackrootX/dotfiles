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
LOCAL_ZPROFILE="${HOME}/.zprofile"
LOCAL_ZSHRC="${HOME}/.zshrc"
LOCAL_ZSH_PLUGINS="${HOME}/.zsh_plugins.txt"
LOCAL_STARSHIP_CONFIG="${HOME}/.config/starship.toml"
LOCAL_GHOSTTY_DIR="${HOME}/.config/ghostty"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"

log() {
  printf '[bootstrap] %s\n' "$1"
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

  local installer_dir
  installer_dir="$(mktemp -d)"

  log "Installing Homebrew"
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_TUNA_GIT_MIRROR}/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_TUNA_GIT_MIRROR}/homebrew-core.git"
  export HOMEBREW_INSTALL_FROM_API=1

  git clone --depth=1 "${HOMEBREW_TUNA_GIT_MIRROR}/install.git" "${installer_dir}/brew-install"
  NONINTERACTIVE=1 /bin/bash "${installer_dir}/brew-install/install.sh"
  rm -rf "${installer_dir}"
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

install_brew_bundle() {
  if [[ ! -f "${BREWFILE}" ]]; then
    printf 'Brewfile not found: %s\n' "${BREWFILE}" >&2
    exit 1
  fi

  log "Installing Homebrew bundle from ${BREWFILE}"
  brew bundle install --verbose --file="${BREWFILE}"
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
  printf 'Press Enter to run `op signin` now, or type \"skip\" to continue without signing in: '
  IFS= read -r choice

  if [[ "${choice}" == "skip" ]]; then
    log "Skipping 1Password sign-in checkpoint by user request"
    return
  fi

  log "Starting 1Password CLI sign-in"
  if ! op signin; then
    printf '1Password CLI sign-in did not complete successfully.\n' >&2
    printf 'Rerun bootstrap later or sign in manually with `op signin`.\n' >&2
    exit 1
  fi

  log "1Password CLI sign-in complete"
}

install_mise_toolchains() {
  if ! command -v mise >/dev/null 2>&1; then
    printf 'mise is required but was not found after Brewfile install.\n' >&2
    exit 1
  fi

  log "Installing latest Node.js and Bun with mise"
  mise use -g -y node@latest bun@latest
}

main() {
  require_macos
  install_homebrew
  ensure_brew_in_path
  configure_homebrew_china_mirror
  link_zprofile
  link_zshrc
  link_zsh_plugins
  link_starship_config
  link_ghostty_config
  install_brew_bundle
  run_1password_checkpoint
  install_mise_toolchains
  log "Bootstrap complete"
}

main "$@"

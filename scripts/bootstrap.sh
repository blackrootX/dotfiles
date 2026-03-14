#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BREWFILE="${REPO_ROOT}/Brewfile"
CONFIGS_DIR="${REPO_ROOT}/configs"
REPO_ZPROFILE="${CONFIGS_DIR}/zsh/.zprofile"
REPO_ZSHRC="${CONFIGS_DIR}/zsh/.zshrc"
REPO_ZSH_PLUGINS="${CONFIGS_DIR}/zsh/.zsh_plugins.txt"
LOCAL_ZPROFILE="${HOME}/.zprofile"
LOCAL_ZSHRC="${HOME}/.zshrc"
LOCAL_ZSH_PLUGINS="${HOME}/.zsh_plugins.txt"
LOCAL_ZSH_PLUGIN_BUNDLE="${HOME}/.zsh_plugins.zsh"
LOCAL_CONFIG_DIR="${HOME}/.config"
LOCAL_SSH_DIR="${HOME}/.ssh"
LOCAL_MISE_CONFIG="${HOME}/.config/mise/config.toml"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"
HOMEBREW_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
DEFAULT_ICLOUD_CONFIG_DIR="${HOME}/Library/Mobile Documents/com~apple~CloudDocs/dev/configs"
ICLOUD_CONFIG_DIR="${ICLOUD_CONFIG_DIR:-${DEFAULT_ICLOUD_CONFIG_DIR}}"
ICLOUD_SSH_DIR="${ICLOUD_SSH_DIR:-${ICLOUD_CONFIG_DIR}/.ssh}"

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

ensure_local_config_root() {
  mkdir -p "${ICLOUD_CONFIG_DIR}"

  if [[ -L "${LOCAL_CONFIG_DIR}" ]]; then
    local current_target
    current_target="$(readlink "${LOCAL_CONFIG_DIR}")"

    if [[ "${current_target}" == "${ICLOUD_CONFIG_DIR}" ]]; then
      log "Local .config already points to iCloud config root"
      return
    fi

    log "Replacing existing .config symlink"
    rm -f "${LOCAL_CONFIG_DIR}"
  elif [[ -e "${LOCAL_CONFIG_DIR}" ]]; then
    local backup_path
    backup_path="${LOCAL_CONFIG_DIR}.pre-icloud-link.$(date +%Y%m%d%H%M%S)"
    log "Moving existing .config to backup at ${backup_path}"
    mv "${LOCAL_CONFIG_DIR}" "${backup_path}"
  fi

  log "Linking ${LOCAL_CONFIG_DIR} to iCloud config root ${ICLOUD_CONFIG_DIR}"
  ln -s "${ICLOUD_CONFIG_DIR}" "${LOCAL_CONFIG_DIR}"
}

ensure_local_ssh_root() {
  mkdir -p "${ICLOUD_SSH_DIR}"
  chmod 700 "${ICLOUD_SSH_DIR}"

  if [[ -L "${LOCAL_SSH_DIR}" ]]; then
    local current_target
    current_target="$(readlink "${LOCAL_SSH_DIR}")"

    if [[ "${current_target}" == "${ICLOUD_SSH_DIR}" ]]; then
      log "Local .ssh already points to iCloud SSH root"
      return
    fi

    log "Replacing existing .ssh symlink"
    rm -f "${LOCAL_SSH_DIR}"
  elif [[ -e "${LOCAL_SSH_DIR}" ]]; then
    local backup_path
    backup_path="${LOCAL_SSH_DIR}.pre-icloud-link.$(date +%Y%m%d%H%M%S)"
    log "Moving existing .ssh to backup at ${backup_path}"
    mv "${LOCAL_SSH_DIR}" "${backup_path}"
  fi

  log "Linking ${LOCAL_SSH_DIR} to iCloud SSH root ${ICLOUD_SSH_DIR}"
  ln -s "${ICLOUD_SSH_DIR}" "${LOCAL_SSH_DIR}"
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

prime_antidote_bundle() {
  local antidote_script
  antidote_script=""

  if [[ ! -f "${LOCAL_ZSH_PLUGINS}" ]]; then
    log "Skipping Antidote bundle generation because ${LOCAL_ZSH_PLUGINS} is missing"
    return
  fi

  for antidote_prefix in /opt/homebrew /usr/local; do
    if [[ -f "${antidote_prefix}/share/antidote/antidote.zsh" ]]; then
      antidote_script="${antidote_prefix}/share/antidote/antidote.zsh"
      break
    fi
  done

  if [[ -z "${antidote_script}" ]]; then
    log "Skipping Antidote bundle generation because antidote is not installed yet"
    return
  fi

  log "Generating Antidote plugin bundle"
  ANTIDOTE_SCRIPT="${antidote_script}" \
  LOCAL_ZSH_PLUGINS="${LOCAL_ZSH_PLUGINS}" \
  LOCAL_ZSH_PLUGIN_BUNDLE="${LOCAL_ZSH_PLUGIN_BUNDLE}" \
    zsh -fc '
      source "${ANTIDOTE_SCRIPT}"
      antidote bundle < "${LOCAL_ZSH_PLUGINS}" > "${LOCAL_ZSH_PLUGIN_BUNDLE}"
    '
}

install_mise_node_tools() {
  if ! command -v mise >/dev/null 2>&1; then
    printf 'mise is required but was not found after Brewfile install.\n' >&2
    exit 1
  fi

  if [[ ! -f "${LOCAL_MISE_CONFIG}" ]]; then
    printf 'mise config not found: %s\n' "${LOCAL_MISE_CONFIG}" >&2
    exit 1
  fi

  log "Trusting mise config"
  mise trust "${LOCAL_MISE_CONFIG}"

  if grep -q '"pipx:' "${LOCAL_MISE_CONFIG}" && ! command -v pipx >/dev/null 2>&1; then
    log "Installing pipx for repo-managed mise pipx tools"
    brew install pipx
  fi

  log "Installing mise tools from global config"
  if ! mise install -y; then
    log "Retrying mise install with source builds enabled"
    MISE_ALL_COMPILE=1 mise install -y
  fi

  if grep -q '"pipx:browser-use"' "${LOCAL_MISE_CONFIG}"; then
    log "Installing browser-use Chromium runtime"
    mise exec -- uvx browser-use install
  fi
}

main() {
  require_macos
  refresh_sudo
  install_homebrew
  ensure_brew_in_path
  configure_homebrew_china_mirror
  ensure_local_config_root
  ensure_local_ssh_root
  link_zprofile
  link_zshrc
  link_zsh_plugins
  install_brew_bundle
  prime_antidote_bundle
  install_mise_node_tools
  log "Bootstrap complete"
}

main "$@"

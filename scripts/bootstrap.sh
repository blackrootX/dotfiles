#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BREWFILE="${REPO_ROOT}/Brewfile"
REPO_ZSHRC="${REPO_ROOT}/zsh/.zshrc"
LOCAL_ZSHRC="${HOME}/.zshrc"
LOCAL_ZSHRC_BACKUP="${HOME}/.zshrc.pre-dotfiles-backup"
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

link_zshrc() {
  mkdir -p "$(dirname "${REPO_ZSHRC}")"

  if [[ ! -f "${REPO_ZSHRC}" ]]; then
    printf 'Managed zshrc not found: %s\n' "${REPO_ZSHRC}" >&2
    exit 1
  fi

  if [[ -L "${LOCAL_ZSHRC}" ]]; then
    local current_target
    current_target="$(readlink "${LOCAL_ZSHRC}")"

    if [[ "${current_target}" == "${REPO_ZSHRC}" ]]; then
      log "Local .zshrc already points to repo-managed zshrc"
      return
    fi

    if [[ ! -e "${LOCAL_ZSHRC_BACKUP}" && ! -L "${LOCAL_ZSHRC_BACKUP}" ]]; then
      log "Backing up existing .zshrc symlink to ${LOCAL_ZSHRC_BACKUP}"
      mv "${LOCAL_ZSHRC}" "${LOCAL_ZSHRC_BACKUP}"
    else
      log "Existing .zshrc backup already present at ${LOCAL_ZSHRC_BACKUP}"
      rm -f "${LOCAL_ZSHRC}"
    fi
  elif [[ -e "${LOCAL_ZSHRC}" ]]; then
    if [[ ! -e "${LOCAL_ZSHRC_BACKUP}" && ! -L "${LOCAL_ZSHRC_BACKUP}" ]]; then
      log "Backing up existing .zshrc to ${LOCAL_ZSHRC_BACKUP}"
      mv "${LOCAL_ZSHRC}" "${LOCAL_ZSHRC_BACKUP}"
    else
      log "Existing .zshrc backup already present at ${LOCAL_ZSHRC_BACKUP}"
      rm -f "${LOCAL_ZSHRC}"
    fi
  fi

  log "Linking ${LOCAL_ZSHRC} to repo-managed zshrc"
  ln -s "${REPO_ZSHRC}" "${LOCAL_ZSHRC}"
}

install_brew_bundle() {
  if [[ ! -f "${BREWFILE}" ]]; then
    printf 'Brewfile not found: %s\n' "${BREWFILE}" >&2
    exit 1
  fi

  log "Installing Homebrew bundle from ${BREWFILE}"
  brew bundle install --file="${BREWFILE}"
}

main() {
  require_macos
  install_homebrew
  ensure_brew_in_path
  configure_homebrew_china_mirror
  link_zshrc
  install_brew_bundle
  log "Bootstrap complete"
}

main "$@"

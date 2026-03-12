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
  printf '[uninstall] %s\n' "$1"
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
    return 0
  fi

  local prefix
  prefix="$(brew_prefix_for_arch)"

  if [[ -x "${prefix}/bin/brew" ]]; then
    eval "$("${prefix}/bin/brew" shellenv)"
    return 0
  fi

  return 1
}

uninstall_tracked_brewfile_entries() {
  if [[ ! -f "${BREWFILE}" ]]; then
    log "Brewfile not found, skipping tracked package removal"
    return
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*brew[[:space:]]+\"([^\"]+)\" ]]; then
      local formula
      formula="${BASH_REMATCH[1]}"

      if brew list --formula "${formula}" >/dev/null 2>&1; then
        log "Uninstalling tracked formula: ${formula}"
        brew uninstall --formula "${formula}"
      else
        log "Tracked formula not installed: ${formula}"
      fi
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
      local cask
      cask="${BASH_REMATCH[1]}"

      if brew list --cask "${cask}" >/dev/null 2>&1; then
        log "Uninstalling tracked cask: ${cask}"
        brew uninstall --cask "${cask}"
      else
        log "Tracked cask not installed: ${cask}"
      fi
    fi
  done < "${BREWFILE}"
}

uninstall_remaining_formulae() {
  local formulae
  formulae="$(brew list --formula)"

  if [[ -z "${formulae}" ]]; then
    return
  fi

  log "Removing remaining Homebrew formulae"
  while IFS= read -r formula; do
    [[ -z "${formula}" ]] && continue
    brew uninstall --formula "${formula}"
  done <<< "${formulae}"
}

uninstall_casks() {
  local casks
  casks="$(brew list --cask 2>/dev/null || true)"

  if [[ -z "${casks}" ]]; then
    return
  fi

  log "Removing installed Homebrew casks"
  while IFS= read -r cask; do
    [[ -z "${cask}" ]] && continue
    brew uninstall --cask "${cask}"
  done <<< "${casks}"
}

uninstall_homebrew() {
  local installer_dir
  installer_dir="$(mktemp -d)"

  log "Uninstalling Homebrew"
  git clone --depth=1 "${HOMEBREW_TUNA_GIT_MIRROR}/install.git" "${installer_dir}/brew-install"
  NONINTERACTIVE=1 /bin/bash "${installer_dir}/brew-install/uninstall.sh"
  rm -rf "${installer_dir}"
}

cleanup_zshrc() {
  if [[ -L "${LOCAL_ZSHRC}" ]]; then
    local current_target
    current_target="$(readlink "${LOCAL_ZSHRC}")"

    if [[ "${current_target}" == "${REPO_ZSHRC}" ]]; then
      log "Removing repo-managed .zshrc symlink"
      rm -f "${LOCAL_ZSHRC}"
    fi
  fi

  if [[ -e "${LOCAL_ZSHRC_BACKUP}" ]]; then
    log "Restoring previous .zshrc from backup"
    mv "${LOCAL_ZSHRC_BACKUP}" "${LOCAL_ZSHRC}"
  fi
}

main() {
  require_macos

  if ! ensure_brew_in_path; then
    cleanup_zshrc
    log "Homebrew is not installed, cleaned up shell config if needed"
    exit 0
  fi

  uninstall_tracked_brewfile_entries
  uninstall_remaining_formulae
  uninstall_casks
  uninstall_homebrew
  cleanup_zshrc
  log "Uninstall complete"
}

main "$@"

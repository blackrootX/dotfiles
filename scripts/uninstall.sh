#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BREWFILE="${REPO_ROOT}/Brewfile"
REPO_ZPROFILE="${REPO_ROOT}/zsh/.zprofile"
REPO_ZSHRC="${REPO_ROOT}/zsh/.zshrc"
REPO_ZSH_PLUGINS="${REPO_ROOT}/zsh/.zsh_plugins.txt"
REPO_STARSHIP_CONFIG="${REPO_ROOT}/starship/starship.toml"
LOCAL_ZPROFILE="${HOME}/.zprofile"
LOCAL_ZPROFILE_BACKUP="${HOME}/.zprofile.pre-dotfiles-backup"
LOCAL_ZSHRC="${HOME}/.zshrc"
LOCAL_ZSHRC_BACKUP="${HOME}/.zshrc.pre-dotfiles-backup"
LOCAL_ZSH_PLUGINS="${HOME}/.zsh_plugins.txt"
LOCAL_ZSH_PLUGINS_BACKUP="${HOME}/.zsh_plugins.txt.pre-dotfiles-backup"
LOCAL_ZSH_PLUGIN_BUNDLE="${HOME}/.zsh_plugins.zsh"
LOCAL_ANTIDOTE_DIR="${HOME}/Library/Caches/antidote"
LOCAL_STARSHIP_CONFIG="${HOME}/.config/starship.toml"
LOCAL_STARSHIP_CONFIG_BACKUP="${HOME}/.config/starship.toml.pre-dotfiles-backup"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"
CLEANUP_COMPLETE=0

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

  local -a formulae=()
  local -a casks=()

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*brew[[:space:]]+\"([^\"]+)\" ]]; then
      formulae+=("${BASH_REMATCH[1]}")
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
      casks+=("${BASH_REMATCH[1]}")
    fi
  done < "${BREWFILE}"

  local formula
  for (( idx=${#formulae[@]}-1; idx>=0; idx-- )); do
    formula="${formulae[idx]}"

    if brew list --formula "${formula}" >/dev/null 2>&1; then
      log "Uninstalling tracked formula: ${formula}"
      brew uninstall --formula "${formula}"
    else
      log "Tracked formula not installed: ${formula}"
    fi
  done

  local cask
  for (( idx=${#casks[@]}-1; idx>=0; idx-- )); do
    cask="${casks[idx]}"

    if brew list --cask "${cask}" >/dev/null 2>&1; then
      log "Uninstalling tracked cask: ${cask}"
      brew uninstall --cask "${cask}"
    else
      log "Tracked cask not installed: ${cask}"
    fi
  done
}

uninstall_remaining_formulae() {
  local -a formulae=()
  local formula

  while IFS= read -r formula; do
    [[ -z "${formula}" ]] && continue
    formulae+=("${formula}")
  done < <(brew list --formula)

  if [[ "${#formulae[@]}" -eq 0 ]]; then
    return
  fi

  log "Removing remaining Homebrew formulae"
  for (( idx=${#formulae[@]}-1; idx>=0; idx-- )); do
    formula="${formulae[idx]}"
    [[ -z "${formula}" ]] && continue
    brew uninstall --formula "${formula}"
  done
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

cleanup_managed_file() {
  local source_path="$1"
  local target_path="$2"
  local backup_path="$3"
  local label="$4"

  if [[ -L "${target_path}" ]]; then
    local current_target
    current_target="$(readlink "${target_path}")"

    if [[ "${current_target}" == "${source_path}" ]]; then
      log "Removing repo-managed ${label} symlink"
      rm -f "${target_path}"
    fi
  fi

  if [[ -e "${backup_path}" || -L "${backup_path}" ]]; then
    log "Restoring previous ${label} from backup"
    mv "${backup_path}" "${target_path}"
  fi
}

cleanup_zprofile() {
  cleanup_managed_file "${REPO_ZPROFILE}" "${LOCAL_ZPROFILE}" "${LOCAL_ZPROFILE_BACKUP}" ".zprofile"
}

cleanup_zshrc() {
  cleanup_managed_file "${REPO_ZSHRC}" "${LOCAL_ZSHRC}" "${LOCAL_ZSHRC_BACKUP}" ".zshrc"
}

cleanup_zsh_plugins() {
  cleanup_managed_file \
    "${REPO_ZSH_PLUGINS}" \
    "${LOCAL_ZSH_PLUGINS}" \
    "${LOCAL_ZSH_PLUGINS_BACKUP}" \
    ".zsh_plugins.txt"
}

cleanup_antidote_artifacts() {
  if [[ -f "${LOCAL_ZSH_PLUGIN_BUNDLE}" || -L "${LOCAL_ZSH_PLUGIN_BUNDLE}" ]]; then
    log "Removing generated Antidote bundle"
    rm -f "${LOCAL_ZSH_PLUGIN_BUNDLE}"
  fi

  if [[ -d "${LOCAL_ANTIDOTE_DIR}" ]]; then
    log "Removing Antidote cache directory"
    rm -rf "${LOCAL_ANTIDOTE_DIR}"
  fi
}

cleanup_starship_config() {
  cleanup_managed_file \
    "${REPO_STARSHIP_CONFIG}" \
    "${LOCAL_STARSHIP_CONFIG}" \
    "${LOCAL_STARSHIP_CONFIG_BACKUP}" \
    "starship config"
}

cleanup_managed_configs() {
  if [[ "${CLEANUP_COMPLETE}" -eq 1 ]]; then
    return
  fi

  cleanup_starship_config
  cleanup_zprofile
  cleanup_zshrc
  cleanup_zsh_plugins
  cleanup_antidote_artifacts
  CLEANUP_COMPLETE=1
}

main() {
  require_macos
  trap cleanup_managed_configs EXIT

  if ! ensure_brew_in_path; then
    log "Homebrew is not installed, cleaned up shell config if needed"
    exit 0
  fi

  uninstall_tracked_brewfile_entries
  uninstall_remaining_formulae
  uninstall_casks
  uninstall_homebrew
  log "Uninstall complete"
}

main "$@"

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
LOCAL_ANTIDOTE_DIR="${HOME}/Library/Caches/antidote"
LEGACY_ZPROFILE_BACKUP="${HOME}/.zprofile.pre-dotfiles-backup"
LEGACY_ZSHRC_BACKUP="${HOME}/.zshrc.pre-dotfiles-backup"
LEGACY_ZSH_PLUGINS_BACKUP="${HOME}/.zsh_plugins.txt.pre-dotfiles-backup"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"
HOMEBREW_UNINSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh"
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
  local line

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if [[ "${line}" =~ ^[[:space:]]*brew[[:space:]]+\"([^\"]+)\" ]]; then
      formulae+=("${BASH_REMATCH[1]}")
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*cask[[:space:]]+\"([^\"]+)\" ]]; then
      casks+=("${BASH_REMATCH[1]}")
    fi
  done < "${BREWFILE}"

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
  local uninstall_script
  uninstall_script="$(mktemp)"

  log "Uninstalling Homebrew"
  curl -fsSL "${HOMEBREW_UNINSTALL_SCRIPT_URL}" -o "${uninstall_script}"
  NONINTERACTIVE=1 /bin/bash "${uninstall_script}"
  rm -f "${uninstall_script}"
}

cleanup_managed_file() {
  local source_path="$1"
  local target_path="$2"
  local label="$3"

  if [[ -L "${target_path}" ]]; then
    local current_target
    current_target="$(readlink "${target_path}")"

    if [[ "${current_target}" == "${source_path}" ]]; then
      log "Removing repo-managed ${label} symlink"
      rm -f "${target_path}"
    fi
  fi
}

cleanup_zprofile() {
  cleanup_managed_file "${REPO_ZPROFILE}" "${LOCAL_ZPROFILE}" ".zprofile"
}

cleanup_zshrc() {
  cleanup_managed_file "${REPO_ZSHRC}" "${LOCAL_ZSHRC}" ".zshrc"
}

cleanup_zsh_plugins() {
  cleanup_managed_file \
    "${REPO_ZSH_PLUGINS}" \
    "${LOCAL_ZSH_PLUGINS}" \
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

cleanup_legacy_backups() {
  local legacy_path
  for legacy_path in \
    "${LEGACY_ZPROFILE_BACKUP}" \
    "${LEGACY_ZSHRC_BACKUP}" \
    "${LEGACY_ZSH_PLUGINS_BACKUP}"; do
    if [[ -e "${legacy_path}" || -L "${legacy_path}" ]]; then
      log "Removing legacy backup ${legacy_path}"
      rm -rf "${legacy_path}"
    fi
  done
}

print_shell_restart_notice() {
  local exit_status="$1"

  if [[ "${exit_status}" -eq 0 ]]; then
    cat <<'EOF'
[uninstall] Homebrew removal is complete.
[uninstall] If this current shell still shows missing-command errors for old Homebrew tools,
[uninstall] start a fresh shell with: exec /bin/zsh -f
EOF
    return
  fi

  cat <<'EOF'
[uninstall] Cleanup finished, but Homebrew uninstall did not complete successfully.
[uninstall] If Homebrew commands are still available in this shell, the uninstall step likely failed before removal finished.
EOF
}

cleanup_managed_configs() {
  local exit_status=$?

  if [[ "${CLEANUP_COMPLETE}" -eq 1 ]]; then
    return
  fi

  cleanup_zprofile
  cleanup_zshrc
  cleanup_zsh_plugins
  cleanup_antidote_artifacts
  cleanup_legacy_backups
  print_shell_restart_notice "${exit_status}"
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
  uninstall_casks
  uninstall_remaining_formulae
  uninstall_homebrew
  log "Uninstall complete"
}

main "$@"

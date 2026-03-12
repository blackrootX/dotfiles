#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FORMULAE_FILE="${REPO_ROOT}/manifests/brew-formulae.txt"

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

uninstall_tracked_formulae() {
  if [[ ! -f "${FORMULAE_FILE}" ]]; then
    log "Formula manifest not found, skipping tracked formula removal"
    return
  fi

  while IFS= read -r formula || [[ -n "${formula}" ]]; do
    [[ -z "${formula}" ]] && continue
    [[ "${formula}" =~ ^# ]] && continue

    if brew list --formula "${formula}" >/dev/null 2>&1; then
      log "Uninstalling tracked formula: ${formula}"
      brew uninstall --formula "${formula}"
    else
      log "Tracked formula not installed: ${formula}"
    fi
  done < "${FORMULAE_FILE}"
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
  log "Uninstalling Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
}

main() {
  require_macos

  if ! ensure_brew_in_path; then
    log "Homebrew is not installed, nothing to do"
    exit 0
  fi

  uninstall_tracked_formulae
  uninstall_remaining_formulae
  uninstall_casks
  uninstall_homebrew
  log "Uninstall complete"
}

main "$@"

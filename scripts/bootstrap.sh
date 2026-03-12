#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
FORMULAE_FILE="${REPO_ROOT}/manifests/brew-formulae.txt"

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

  log "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  ensure_brew_in_path
}

install_formulae() {
  if [[ ! -f "${FORMULAE_FILE}" ]]; then
    printf 'Formula manifest not found: %s\n' "${FORMULAE_FILE}" >&2
    exit 1
  fi

  while IFS= read -r formula || [[ -n "${formula}" ]]; do
    [[ -z "${formula}" ]] && continue
    [[ "${formula}" =~ ^# ]] && continue

    if brew list --formula "${formula}" >/dev/null 2>&1; then
      log "Formula already installed: ${formula}"
      continue
    fi

    log "Installing formula: ${formula}"
    brew install "${formula}"
  done < "${FORMULAE_FILE}"
}

main() {
  require_macos
  install_homebrew
  ensure_brew_in_path
  install_formulae
  log "Bootstrap complete"
}

main "$@"

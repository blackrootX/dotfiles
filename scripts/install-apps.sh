#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
  printf '[apps] %s\n' "$1"
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

  printf 'Homebrew is required. Run ./scripts/bootstrap.sh first.\n' >&2
  exit 1
}

ensure_mas_installed() {
  if command -v mas >/dev/null 2>&1; then
    return
  fi

  log "Installing mas"
  brew install mas
}

install_app() {
  local app_id="$1"
  local app_name="$2"

  if mas list | awk '{print $1}' | grep -qx "${app_id}"; then
    log "App already installed: ${app_name}"
    return
  fi

  log "Installing App Store app: ${app_name}"
  if mas install "${app_id}"; then
    return
  fi

  cat >&2 <<EOF
Failed to install ${app_name} from the Mac App Store.
If you already signed in, open the App Store app once and finish any pending prompts,
then rerun this script.
EOF
  exit 1
}

main() {
  require_macos
  ensure_brew_in_path
  ensure_mas_installed
  install_app "937984704" "Amphetamine"
  install_app "1551531632" "AutoSwitchInput Pro"
  install_app "1136220934" "Infuse"
  install_app "944848654" "NeteaseMusic"
  install_app "1006087419" "SnippetsLab"
  install_app "836500024" "WeChat"
  install_app "497799835" "Xcode"
  log "App installation complete"
}

main "$@"

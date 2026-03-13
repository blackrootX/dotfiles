#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"

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

configure_homebrew_china_mirror() {
  export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
  export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
  export HOMEBREW_BREW_GIT_REMOTE="${HOMEBREW_TUNA_GIT_MIRROR}/brew.git"
  export HOMEBREW_CORE_GIT_REMOTE="${HOMEBREW_TUNA_GIT_MIRROR}/homebrew-core.git"
  export HOMEBREW_INSTALL_FROM_API=1
}

ensure_mas_installed() {
  if command -v mas >/dev/null 2>&1; then
    return
  fi

  log "Installing mas"
  brew install mas
}

require_app_store_login() {
  if mas account >/dev/null 2>&1; then
    return
  fi

  cat >&2 <<'EOF'
Sign in to the Mac App Store first, then rerun this script.
You can open the App Store app and confirm your account there.
EOF
  exit 1
}

install_app() {
  local app_id="$1"
  local app_name="$2"

  if mas list | awk '{print $1}' | grep -qx "${app_id}"; then
    log "App already installed: ${app_name}"
    return
  fi

  log "Installing App Store app: ${app_name}"
  mas install "${app_id}"
}

main() {
  require_macos
  ensure_brew_in_path
  configure_homebrew_china_mirror
  ensure_mas_installed
  require_app_store_login
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

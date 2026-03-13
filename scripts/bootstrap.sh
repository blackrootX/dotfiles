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
REPO_MISE_CONFIG="${CONFIGS_DIR}/mise/config.toml"
REPO_EZA_CONFIG_DIR="${CONFIGS_DIR}/eza"
REPO_GIT_CONFIG_DIR="${CONFIGS_DIR}/git"
REPO_GITCONFIG="${REPO_GIT_CONFIG_DIR}/.gitconfig"
REPO_GH_CONFIG="${REPO_GIT_CONFIG_DIR}/config.yml"
REPO_SSH_CONFIG_DIR="${CONFIGS_DIR}/ssh"
REPO_SSH_CONFIG="${REPO_SSH_CONFIG_DIR}/config"
REPO_SSH_PUBLIC_KEY_ED25519="${REPO_SSH_CONFIG_DIR}/id_ed25519.pub"
REPO_SSH_PUBLIC_KEY_MACAIR="${REPO_SSH_CONFIG_DIR}/{macair}.pub"
REPO_ZED_SETTINGS_TEMPLATE="${CONFIGS_DIR}/zed/settings.json.tmpl"
REPO_ZED_KEYMAP="${CONFIGS_DIR}/zed/keymap.json"
LOCAL_ZPROFILE="${HOME}/.zprofile"
LOCAL_ZSHRC="${HOME}/.zshrc"
LOCAL_ZSH_PLUGINS="${HOME}/.zsh_plugins.txt"
LOCAL_ZSH_PLUGIN_BUNDLE="${HOME}/.zsh_plugins.zsh"
LOCAL_STARSHIP_CONFIG="${HOME}/.config/starship.toml"
LOCAL_GHOSTTY_DIR="${HOME}/.config/ghostty"
LOCAL_MISE_CONFIG="${HOME}/.config/mise/config.toml"
LOCAL_EZA_CONFIG_DIR="${HOME}/.config/eza"
LOCAL_GITCONFIG="${HOME}/.gitconfig"
LOCAL_GH_CONFIG="${HOME}/.config/gh/config.yml"
LOCAL_SSH_CONFIG="${HOME}/.ssh/config"
LOCAL_SSH_PRIVATE_KEY_ED25519="${HOME}/.ssh/id_ed25519"
LOCAL_SSH_PRIVATE_KEY_MACAIR="${HOME}/.ssh/{macair}"
LOCAL_SSH_PUBLIC_KEY_ED25519="${HOME}/.ssh/id_ed25519.pub"
LOCAL_SSH_PUBLIC_KEY_MACAIR="${HOME}/.ssh/{macair}.pub"
LOCAL_ZED_SETTINGS="${HOME}/.config/zed/settings.json"
LOCAL_ZED_KEYMAP="${HOME}/.config/zed/keymap.json"
HOMEBREW_TUNA_GIT_MIRROR="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew"
HOMEBREW_INSTALL_SCRIPT_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
CONTEXT7_VAULT="Employee"
CONTEXT7_ITEM_TITLE="Context7 API Key"
ONEPASSWORD_SSH_AGENT_SOCKET="${HOME}/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"

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

link_mise_config() {
  link_managed_file \
    "${REPO_MISE_CONFIG}" \
    "${LOCAL_MISE_CONFIG}" \
    "mise config"
}

link_eza_config() {
  link_managed_file \
    "${REPO_EZA_CONFIG_DIR}" \
    "${LOCAL_EZA_CONFIG_DIR}" \
    "eza config"
}

link_gitconfig() {
  link_managed_file \
    "${REPO_GITCONFIG}" \
    "${LOCAL_GITCONFIG}" \
    "Git config"
}

link_gh_config() {
  link_managed_file \
    "${REPO_GH_CONFIG}" \
    "${LOCAL_GH_CONFIG}" \
    "GitHub CLI config"
}

link_ssh_config() {
  link_managed_file \
    "${REPO_SSH_CONFIG}" \
    "${LOCAL_SSH_CONFIG}" \
    "SSH config"
}

link_ssh_public_keys() {
  link_managed_file \
    "${REPO_SSH_PUBLIC_KEY_ED25519}" \
    "${LOCAL_SSH_PUBLIC_KEY_ED25519}" \
    "SSH public key id_ed25519.pub"

  link_managed_file \
    "${REPO_SSH_PUBLIC_KEY_MACAIR}" \
    "${LOCAL_SSH_PUBLIC_KEY_MACAIR}" \
    "SSH public key {macair}.pub"
}

sync_ssh_private_keys_from_1password() {
  if ! command -v op >/dev/null 2>&1; then
    log "1Password CLI is not installed, skipping SSH private key sync"
    return
  fi

  if ! op whoami >/dev/null 2>&1; then
    log "1Password CLI is not signed in, skipping SSH private key sync"
    return
  fi

  if ! command -v python3 >/dev/null 2>&1; then
    log "python3 is unavailable, skipping SSH private key sync from 1Password"
    return
  fi

  if ! command -v ssh-keygen >/dev/null 2>&1; then
    log "ssh-keygen is unavailable, skipping SSH private key sync from 1Password"
    return
  fi

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh"

  log "Syncing SSH private keys from 1Password into ~/.ssh"
  python3 - \
    "${LOCAL_SSH_PUBLIC_KEY_ED25519}" "${LOCAL_SSH_PRIVATE_KEY_ED25519}" \
    "${LOCAL_SSH_PUBLIC_KEY_MACAIR}" "${LOCAL_SSH_PRIVATE_KEY_MACAIR}" <<'PY'
import json
import os
import stat
import subprocess
import sys
import tempfile
from pathlib import Path


def run(*args: str) -> str:
    return subprocess.check_output(args, text=True)


def read_json(*args: str):
    return json.loads(run(*args))


def normalize_public_key(raw: str) -> str:
    parts = raw.strip().split()
    if len(parts) < 2:
        return raw.strip()
    return " ".join(parts[:2])


pairs = []
argv = sys.argv[1:]
for idx in range(0, len(argv), 2):
    public_path = Path(argv[idx])
    private_path = Path(argv[idx + 1])
    if public_path.exists():
        pairs.append((public_path, private_path))

if not pairs:
    print("[bootstrap] No tracked SSH public keys were found locally; skipping private key sync")
    raise SystemExit(0)

items = read_json("op", "item", "list", "--categories", "SSH Key", "--format", "json")
matches = {}

for item in items:
    vault = item.get("vault") or {}
    vault_id = vault.get("id")
    item_id = item.get("id")
    title = item.get("title", item_id)
    if not vault_id or not item_id:
        continue

    private_reference = f"op://{vault_id}/{item_id}/private key?ssh-format=openssh"

    try:
        private_key = run("op", "read", private_reference)
    except subprocess.CalledProcessError:
        continue

    with tempfile.NamedTemporaryFile("w", delete=False) as handle:
        handle.write(private_key)
        temp_private_path = handle.name

    os.chmod(temp_private_path, stat.S_IRUSR | stat.S_IWUSR)
    try:
        public_value = normalize_public_key(
            run("ssh-keygen", "-y", "-f", temp_private_path)
        )
    except subprocess.CalledProcessError:
        os.unlink(temp_private_path)
        continue
    finally:
        if os.path.exists(temp_private_path):
            os.unlink(temp_private_path)

    if public_value:
        matches[public_value] = {
            "title": title,
            "private_key": private_key,
        }

missing = []

for public_path, private_path in pairs:
    public_value = normalize_public_key(public_path.read_text().strip())
    match = matches.get(public_value)
    if not match:
        missing.append(public_path.name)
        continue

    private_path.write_text(match["private_key"])
    os.chmod(private_path, stat.S_IRUSR | stat.S_IWUSR)
    print(f"[bootstrap] Synced {private_path.name} from 1Password item '{match['title']}'")

if missing:
    print(
        "[bootstrap] Could not find matching 1Password SSH Key items for: "
        + ", ".join(missing),
        file=sys.stderr,
    )
PY
}

render_zed_settings() {
  local context7_api_key escaped_key

  mkdir -p "$(dirname "${LOCAL_ZED_SETTINGS}")"

  if [[ ! -f "${REPO_ZED_SETTINGS_TEMPLATE}" ]]; then
    printf 'Managed Zed settings template not found: %s\n' "${REPO_ZED_SETTINGS_TEMPLATE}" >&2
    exit 1
  fi

  context7_api_key=""
  if command -v op >/dev/null 2>&1 && op whoami >/dev/null 2>&1; then
    context7_api_key="$(op item get "${CONTEXT7_ITEM_TITLE}" --vault "${CONTEXT7_VAULT}" --fields credential 2>/dev/null || true)"
  fi

  if [[ -z "${context7_api_key}" ]]; then
    log "Rendering Zed settings without Context7 API key"
  else
    log "Rendering Zed settings with Context7 API key from 1Password"
  fi

  escaped_key="$(printf '%s' "${context7_api_key}" | sed 's/[\/&]/\\&/g')"
  sed "s/__CONTEXT7_API_KEY__/${escaped_key}/g" "${REPO_ZED_SETTINGS_TEMPLATE}" > "${LOCAL_ZED_SETTINGS}"
}

link_zed_settings() {
  render_zed_settings
}

link_zed_keymap() {
  link_managed_file \
    "${REPO_ZED_KEYMAP}" \
    "${LOCAL_ZED_KEYMAP}" \
    "Zed keymap"
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
  printf 'Run 1Password CLI sign-in now? [y/N]: '
  IFS= read -r choice

  if [[ ! "${choice}" =~ ^[Yy]$ ]]; then
    log "Skipping 1Password sign-in checkpoint by user request"
    return
  fi

  log "Starting 1Password CLI sign-in"
  if ! eval "$(op signin)"; then
    printf '1Password CLI sign-in did not complete successfully.\n' >&2
    printf 'Rerun bootstrap later or sign in manually with `eval $(op signin)`.\n' >&2
    exit 1
  fi

  if ! op whoami >/dev/null 2>&1; then
    printf '1Password CLI sign-in did not leave an active session.\n' >&2
    printf 'Rerun bootstrap later or sign in manually with `eval $(op signin)`.\n' >&2
    exit 1
  fi

  log "1Password CLI sign-in complete"
}

run_1password_ssh_agent_checkpoint() {
  if [[ -S "${ONEPASSWORD_SSH_AGENT_SOCKET}" ]]; then
    log "1Password SSH agent socket is available"
    return
  fi

  if [[ ! -t 0 ]]; then
    log "1Password SSH agent socket is not available yet; configure the 1Password desktop app later if needed"
    return
  fi

  printf '\n'
  printf '1Password SSH agent is not available yet.\n'
  printf 'Open the 1Password desktop app, sign in, and enable SSH agent support.\n'
  printf 'Expected socket: %s\n' "${ONEPASSWORD_SSH_AGENT_SOCKET}"
  printf 'Press Enter to continue once the SSH agent is ready, or use Ctrl-C to stop bootstrap.\n'
  IFS= read -r _

  if [[ -S "${ONEPASSWORD_SSH_AGENT_SOCKET}" ]]; then
    log "1Password SSH agent socket is available"
  else
    log "1Password SSH agent socket is still unavailable; SSH config is in place, but agent-backed auth may not work until 1Password is ready"
  fi
}

install_mise_node_tools() {
  if ! command -v mise >/dev/null 2>&1; then
    printf 'mise is required but was not found after Brewfile install.\n' >&2
    exit 1
  fi

  if [[ ! -f "${REPO_MISE_CONFIG}" ]]; then
    printf 'mise config not found: %s\n' "${REPO_MISE_CONFIG}" >&2
    exit 1
  fi

  log "Trusting repo-managed mise config"
  mise trust "${REPO_MISE_CONFIG}"

  if grep -q '"pipx:' "${REPO_MISE_CONFIG}" && ! command -v pipx >/dev/null 2>&1; then
    log "Installing pipx for repo-managed mise pipx tools"
    brew install pipx
  fi

  log "Installing repo-managed mise tools from global config"
  if ! mise install -C "${CONFIGS_DIR}/mise" -y; then
    log "Retrying mise install with source builds enabled"
    MISE_ALL_COMPILE=1 mise install -C "${CONFIGS_DIR}/mise" -y
  fi

  if grep -q '"pipx:browser-use"' "${REPO_MISE_CONFIG}"; then
    log "Installing browser-use Chromium runtime"
    mise exec -C "${CONFIGS_DIR}/mise" -- uvx browser-use install
  fi
}

main() {
  require_macos
  refresh_sudo
  install_homebrew
  ensure_brew_in_path
  configure_homebrew_china_mirror
  link_zprofile
  link_zshrc
  link_zsh_plugins
  link_starship_config
  link_ghostty_config
  link_mise_config
  link_eza_config
  link_gitconfig
  link_gh_config
  link_ssh_config
  link_ssh_public_keys
  install_brew_bundle
  prime_antidote_bundle
  run_1password_checkpoint
  link_zed_settings
  link_zed_keymap
  sync_ssh_private_keys_from_1password
  run_1password_ssh_agent_checkpoint
  install_mise_node_tools
  log "Bootstrap complete"
}

main "$@"

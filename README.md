# dotfiles

Bootstrap and config management for a new macOS machine.

This repo manages three main things:

- Homebrew taps, formulae, and casks from `Brewfile`
- shell, terminal, editor, Git, and `mise` config via symlinks into `~/`
- a small set of Mac App Store installs via `scripts/install-apps.sh`

## Requirements

- macOS
- `bash`
- network access
- administrator access for Homebrew installation

## Layout

- `Brewfile`: tracked Homebrew taps, formulae, and casks
- `configs/zsh/.zprofile`: linked to `~/.zprofile`
- `configs/zsh/.zshrc`: linked to `~/.zshrc`
- `configs/zsh/.zsh_plugins.txt`: linked to `~/.zsh_plugins.txt`
- `configs/starship/starship.toml`: linked to `~/.config/starship.toml`
- `configs/ghostty/`: linked to `~/.config/ghostty`
- `configs/mise/config.toml`: linked to `~/.config/mise/config.toml`
- `configs/eza/`: linked to `~/.config/eza`
- `configs/git/.gitconfig`: linked to `~/.gitconfig`
- `configs/git/config.yml`: linked to `~/.config/gh/config.yml`
- `~/Library/Mobile Documents/com~apple~CloudDocs/dev/config/ssh/`: linked to `~/.ssh`
- `configs/zed/settings.json.tmpl`: rendered to `~/.config/zed/settings.json`
- `configs/zed/keymap.json`: linked to `~/.config/zed/keymap.json`
- `scripts/bootstrap.sh`: installs Homebrew if needed, links managed config, installs Brewfile entries, and installs repo-managed `mise` tools
- `scripts/install-apps.sh`: installs tracked Mac App Store apps with `mas`
- `scripts/uninstall.sh`: removes tracked Homebrew software, uninstalls Homebrew, and cleans up repo-managed symlinks

## Usage

Bootstrap a machine:

```bash
./scripts/bootstrap.sh
```

By default, bootstrap links `~/.config` to the shared iCloud Drive config root at:

```bash
$HOME/Library/Mobile Documents/com~apple~CloudDocs/dev/config
```

By default, bootstrap also links `~/.ssh` to:

```bash
$HOME/Library/Mobile Documents/com~apple~CloudDocs/dev/config/ssh
```

Override that path for a different machine or layout:

```bash
ICLOUD_CONFIG_DIR="/custom/path/to/config" ./scripts/bootstrap.sh
```

Install tracked App Store apps:

```bash
./scripts/install-apps.sh
```

Remove the managed setup:

```bash
./scripts/uninstall.sh
```

## Bootstrap Flow

`scripts/bootstrap.sh` currently does the following:

- verifies the host is macOS
- refreshes `sudo` credentials in interactive shells
- installs Homebrew from the official installer script when missing
- configures Homebrew to use the Tsinghua bottle/API mirrors after install
- links `~/.config` to the default iCloud Drive config directory and backs up any existing local `~/.config`
- links `~/.ssh` to the default iCloud Drive SSH directory and backs up any existing local `~/.ssh`
- links repo-managed config into:
  - `~/.zprofile`
  - `~/.zshrc`
  - `~/.zsh_plugins.txt`
  - `~/.config/starship.toml`
  - `~/.config/ghostty`
  - `~/.config/mise/config.toml`
  - `~/.config/eza`
  - `~/.gitconfig`
  - `~/.config/gh/config.yml`
- installs Homebrew taps, formulae, and casks from `Brewfile` with per-item progress logs
- pre-generates the Antidote plugin bundle after `antidote` is installed from `Brewfile`
- offers an interactive `y/N` 1Password CLI sign-in checkpoint
- renders `~/.config/zed/settings.json`
- links `~/.config/zed/keymap.json`
- verifies the 1Password SSH agent against the public keys already present in the iCloud-backed `~/.ssh/`
- trusts the repo-managed `mise` config and installs its declared tools
- retries `mise` installs with `MISE_ALL_COMPILE=1` if a prebuilt runtime download fails

## Homebrew Scope

`Brewfile` is the source of truth for:

- Homebrew taps
- CLI tools managed by Homebrew
- desktop apps managed by Homebrew cask
- font casks

The bootstrap script installs formulae with `brew install --formula` and casks with `brew install --cask` so Homebrew cannot silently resolve an ambiguous name to the wrong package type.

## Mise Scope

The repo-managed `mise` config lives at `configs/mise/config.toml` and is linked to `~/.config/mise/config.toml`.

That file currently manages:

- `bun`
- `node`
- `python`
- `uv`
- `pipx:browser-use`
- `npm:typescript`
- `npm:typescript-language-server`

This means:

- the repo is the source of truth for global `mise` tool definitions
- `mise activate zsh` in `configs/zsh/.zshrc` exposes those tools in your shell
- bootstrap also runs `uvx browser-use install` so Browser Use's Chromium dependency is installed on a new Mac

## Eza Theme Scope

The repo-managed `eza` theme bundle lives at `configs/eza/` and is linked to `~/.config/eza`.

This means:

- the repo carries the upstream theme files under `configs/eza/themes/`
- `configs/zsh/.zshrc` already exports `EZA_COLORS_THEME="dracula"`
- a new Mac can use the Dracula theme without depending on any other local repo or symlink

## App Store Scope

`scripts/install-apps.sh` currently installs these Mac App Store apps:

- Amphetamine
- AutoSwitchInput Pro
- Infuse
- NeteaseMusic
- SnippetsLab
- WeChat
- Xcode

App Store sign-in is intentionally kept as a manual prerequisite.

## Uninstall Flow

`scripts/uninstall.sh` currently does the following:

- verifies the host is macOS
- removes tracked Homebrew formulae and casks from `Brewfile`
- removes any remaining installed Homebrew formulae and casks
- runs the official Homebrew uninstall script
- cleans up repo-managed symlinks for:
  - zsh config
  - Starship config
  - Ghostty config
  - `mise` config
  - `eza` config
  - Git config
  - GitHub CLI config
  - iCloud-backed `~/.ssh`
  - Zed settings
  - Zed keymap
- removes generated Antidote artifacts
- prints a success or failure notice that reflects the actual uninstall result

## Zed Scope

The repo-managed Zed config lives at `configs/zed/`.

This means:

- `configs/zed/settings.json.tmpl` is rendered to `~/.config/zed/settings.json`
- `configs/zed/keymap.json` is linked to `~/.config/zed/keymap.json`
- other local Zed state such as `conversations/`, `prompts/`, and `themes/` stays outside the repo
- after the 1Password CLI sign-in checkpoint, bootstrap fills the Context7 key from the `Context7 API Key` item in the `Employee` 1Password vault when available
- the tracked settings template intentionally does not include a live `context7_api_key`

## SSH Scope

SSH now lives in iCloud Drive at `~/Library/Mobile Documents/com~apple~CloudDocs/dev/config/ssh/`.

This means:

- bootstrap links `~/.ssh` to that iCloud directory
- SSH config, public keys, private keys, and host trust files all live in the cloud-backed `~/.ssh/`
- after `op` sign-in, bootstrap verifies that the 1Password SSH agent exposes the public keys already stored in that directory
- the SSH config can still point at private key paths in `~/.ssh/` and also use the 1Password SSH agent when the socket at `~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock` is available

## Idempotency

- `./scripts/bootstrap.sh` is safe to rerun
- `./scripts/install-apps.sh` skips already-installed App Store apps
- `./scripts/uninstall.sh` exits cleanly even when Homebrew is already absent

## Notes

- `configs/zsh/.zshrc` sources `~/.zshrc.local` when present
- `configs/zsh/.zprofile` sources `~/.zprofile.local` when present
- `configs/git/config.yml` covers GitHub CLI preferences only; keep `~/.config/gh/hosts.yml` local
- override `ICLOUD_CONFIG_DIR` only if you want `~/.config` to point somewhere other than the default iCloud Drive path
- override `ICLOUD_SSH_DIR` only if you want `~/.ssh` to point somewhere other than `${ICLOUD_CONFIG_DIR}/ssh`
- secrets should stay out of tracked files; prefer local files or `op`-backed runtime injection for secret material

# dotfiles

Bootstrap and config management for a new macOS machine.

This repo manages three main things:

- Homebrew taps, formulae, and casks from `Brewfile`
- zsh shell config via symlinks into `~/`
- a small set of Mac App Store installs via `scripts/install-apps.sh`

All app configs (`~/.config`) and SSH (`~/.ssh`) live in iCloud Drive and sync automatically across Macs.

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
- `scripts/bootstrap.sh`: installs Homebrew if needed, links managed config, installs Brewfile entries, and installs `mise` tools
- `scripts/install-apps.sh`: installs tracked Mac App Store apps with `mas`
- `scripts/uninstall.sh`: removes tracked Homebrew software, uninstalls Homebrew, and cleans up repo-managed symlinks

## Usage

Bootstrap a machine:

```bash
./scripts/bootstrap.sh
```

By default, bootstrap links `~/.config` to the shared iCloud Drive config root at:

```bash
$HOME/Library/Mobile Documents/com~apple~CloudDocs/dev/configs
```

By default, bootstrap also links `~/.ssh` to:

```bash
$HOME/Library/Mobile Documents/com~apple~CloudDocs/dev/configs/.ssh
```

Override that path for a different machine or layout:

```bash
ICLOUD_CONFIG_DIR="/custom/path/to/configs" ./scripts/bootstrap.sh
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
- links `~/.config` to the iCloud Drive config directory and backs up any existing local `~/.config`
- links `~/.ssh` to the iCloud Drive SSH directory and backs up any existing local `~/.ssh`
- links repo-managed zsh config into:
  - `~/.zprofile`
  - `~/.zshrc`
  - `~/.zsh_plugins.txt`
- installs Homebrew taps, formulae, and casks from `Brewfile` with per-item progress logs
- pre-generates the Antidote plugin bundle after `antidote` is installed from `Brewfile`
- trusts the `mise` config (from iCloud-backed `~/.config/mise/config.toml`) and installs its declared tools
- retries `mise` installs with `MISE_ALL_COMPILE=1` if a prebuilt runtime download fails

## Homebrew Scope

`Brewfile` is the source of truth for:

- Homebrew taps
- CLI tools managed by Homebrew
- desktop apps managed by Homebrew cask
- font casks

The bootstrap script installs formulae with `brew install --formula` and casks with `brew install --cask` so Homebrew cannot silently resolve an ambiguous name to the wrong package type.

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
- cleans up repo-managed zsh symlinks
- removes generated Antidote artifacts
- prints a success or failure notice that reflects the actual uninstall result

Note: iCloud-backed `~/.config` and `~/.ssh` symlinks are intentionally preserved by uninstall.

## SSH Scope

SSH lives in iCloud Drive at `~/Library/Mobile Documents/com~apple~CloudDocs/dev/configs/.ssh/`.

This means:

- bootstrap links `~/.ssh` to that iCloud directory
- SSH config, public keys, private keys, and host trust files all live in the cloud-backed `~/.ssh/`
- private keys sync via iCloud so no extraction from 1Password is needed

## Idempotency

- `./scripts/bootstrap.sh` is safe to rerun
- `./scripts/install-apps.sh` skips already-installed App Store apps
- `./scripts/uninstall.sh` exits cleanly even when Homebrew is already absent

## Notes

- `configs/zsh/.zshrc` sources `~/.zshrc.local` when present
- `configs/zsh/.zprofile` sources `~/.zprofile.local` when present
- override `ICLOUD_CONFIG_DIR` only if you want `~/.config` to point somewhere other than the default iCloud Drive path
- override `ICLOUD_SSH_DIR` only if you want `~/.ssh` to point somewhere other than `${ICLOUD_CONFIG_DIR}/.ssh`
- secrets should stay out of tracked files; prefer local files or `op`-backed runtime injection for secret material

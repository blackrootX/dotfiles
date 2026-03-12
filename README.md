# dotfiles

Migration helpers for bringing command-line tooling onto a new Mac.

This v1 focuses on Homebrew packages managed through a `Brewfile`. It proves the bootstrap and uninstall flow with one tracked package, `jq`, while leaving room to add more formulae, casks, `mas`, and config syncing later.

## Requirements

- macOS
- `bash`
- Network access
- Administrator access for Homebrew installation

## Layout

- `scripts/bootstrap.sh`: install Homebrew if needed, then install tracked formulae
- `scripts/install-apps.sh`: install tracked Mac App Store apps with `mas`
- `scripts/uninstall.sh`: remove tracked Homebrew formulae, then uninstall Homebrew
- `Brewfile`: source of truth for Homebrew packages in v1
- `zsh/.zshrc`: tracked zsh config applied to `~/.zshrc` during bootstrap

## Usage

Bootstrap a new Mac:

```bash
./scripts/bootstrap.sh
```

Install tracked App Store apps:

```bash
./scripts/install-apps.sh
```

Remove the tracked Homebrew setup:

```bash
./scripts/uninstall.sh
```

## Current Scope

The bootstrap script currently does the following:

- Verifies the host is macOS
- Installs Homebrew non-interactively from the Tsinghua mirror when missing
- Initializes Homebrew for the current shell session
- Repoints Homebrew brew/core/cask remotes to the Tsinghua China mirror
- Uses the Tsinghua bottle and API mirror for package downloads during bootstrap
- Backs up an existing `~/.zshrc` to `~/.zshrc.pre-dotfiles-backup` when needed
- Links `~/.zshrc` to the tracked `zsh/.zshrc`
- Installs all packages declared in `Brewfile`

The uninstall script currently does the following:

- Verifies the host is macOS
- Cleans up the managed `~/.zshrc` symlink even if Homebrew is already absent
- Uninstalls tracked formulae and casks declared in `Brewfile`
- Attempts to uninstall any remaining Homebrew formulae and casks
- Runs the official Homebrew uninstall script
- Restores the previous `~/.zshrc` from backup when one exists

The app install script currently does the following:

- Verifies the host is macOS
- Requires Homebrew to already be installed
- Ensures `mas` is available
- Requires an active Mac App Store login
- Installs tracked App Store apps such as WeChat

## Idempotency

- Running `./scripts/bootstrap.sh` multiple times is safe. Existing Homebrew installs and already-installed formulae are skipped.
- Running `./scripts/install-apps.sh` multiple times is safe. Already-installed App Store apps are skipped.
- Running `./scripts/uninstall.sh` on a machine without Homebrew exits successfully with a message.

## Roadmap

Planned next steps for this repo:

- Track more `Brewfile` entries such as `cask` and `mas`
- Add config and dotfile sync for shell and CLI tools

## Notes

- v1 intentionally keeps the uninstall scope limited to Homebrew-managed software. It does not remove unrelated shell files, dotfiles, or user configuration.
- The first tracked formula is `jq` so the workflow stays simple and easy to validate.
- The tracked [zsh/.zshrc](/Users/blackpig/Code/Github/dotfiles/zsh/.zshrc) will source `~/.zshrc.local` when present, so each Mac can keep machine-specific zsh settings outside the repo.

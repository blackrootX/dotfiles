# dotfiles

Migration helpers for bringing command-line tooling onto a new Mac.

This v1 focuses on Homebrew formulae only. It proves the bootstrap and uninstall flow with one tracked package, `jq`, while leaving room to add `brew cask`, `mas`, and config syncing later.

## Requirements

- macOS
- `bash`
- Network access
- Administrator access for Homebrew installation

## Layout

- `scripts/bootstrap.sh`: install Homebrew if needed, then install tracked formulae
- `scripts/uninstall.sh`: remove tracked Homebrew formulae, then uninstall Homebrew
- `manifests/brew-formulae.txt`: source of truth for Homebrew formulae in v1

## Usage

Bootstrap a new Mac:

```bash
./scripts/bootstrap.sh
```

Remove the tracked Homebrew setup:

```bash
./scripts/uninstall.sh
```

## Current Scope

The bootstrap script currently does the following:

- Verifies the host is macOS
- Installs Homebrew non-interactively when missing
- Initializes Homebrew for the current shell session
- Installs all formulae listed in `manifests/brew-formulae.txt`

The uninstall script currently does the following:

- Verifies the host is macOS
- Skips cleanly if Homebrew is not installed
- Uninstalls tracked formulae from `manifests/brew-formulae.txt`
- Attempts to uninstall any remaining Homebrew formulae and casks
- Runs the official Homebrew uninstall script

## Idempotency

- Running `./scripts/bootstrap.sh` multiple times is safe. Existing Homebrew installs and already-installed formulae are skipped.
- Running `./scripts/uninstall.sh` on a machine without Homebrew exits successfully with a message.

## Roadmap

Planned next steps for this repo:

- Track `brew cask` applications in a separate manifest
- Track Mac App Store applications with `mas`
- Add config and dotfile sync for shell and CLI tools

## Notes

- v1 intentionally keeps the uninstall scope limited to Homebrew-managed software. It does not remove unrelated shell files, dotfiles, or user configuration.
- The first tracked formula is `jq` so the workflow stays simple and easy to validate.

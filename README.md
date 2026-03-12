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
- `starship/starship.toml`: tracked Starship prompt config applied to `~/.config/starship.toml`
- `zsh/.zprofile`: tracked login-shell config applied to `~/.zprofile`
- `zsh/.zshrc`: tracked zsh config applied to `~/.zshrc` during bootstrap
- `zsh/.zsh_plugins.txt`: tracked Antidote plugin list applied to `~/.zsh_plugins.txt`

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
- Backs up an existing `~/.zprofile` to `~/.zprofile.pre-dotfiles-backup` when needed
- Links `~/.zprofile` to the tracked `zsh/.zprofile`
- Backs up an existing `~/.zshrc` to `~/.zshrc.pre-dotfiles-backup` when needed
- Links `~/.zshrc` to the tracked `zsh/.zshrc`
- Backs up an existing `~/.zsh_plugins.txt` to `~/.zsh_plugins.txt.pre-dotfiles-backup` when needed
- Links `~/.zsh_plugins.txt` to the tracked `zsh/.zsh_plugins.txt`
- Backs up an existing `~/.config/starship.toml` when needed and links the tracked Starship config
- Installs all packages declared in `Brewfile`

The uninstall script currently does the following:

- Verifies the host is macOS
- Cleans up the managed `~/.zprofile` symlink even if Homebrew is already absent
- Cleans up the managed `~/.zshrc` symlink even if Homebrew is already absent
- Cleans up the managed `~/.zsh_plugins.txt` symlink even if Homebrew is already absent
- Cleans up the managed `~/.config/starship.toml` symlink even if Homebrew is already absent
- Uninstalls tracked formulae and casks declared in `Brewfile`
- Attempts to uninstall any remaining Homebrew formulae and casks
- Runs the official Homebrew uninstall script
- Restores the previous `~/.zprofile` from backup when one exists
- Restores the previous `~/.zshrc` from backup when one exists
- Restores the previous `~/.zsh_plugins.txt` from backup when one exists
- Restores the previous `~/.config/starship.toml` from backup when one exists

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

Suggested expansion order for this repo:

1. Expand `Brewfile` coverage for more CLI packages and `cask` apps.
2. Grow `mas` coverage for Mac App Store apps that are better managed through Apple updates.
3. Track shell, Git, terminal, and editor configs that should follow you to a new Mac.
4. Add runtime and toolchain setup such as `mise`, Node, Python tooling, and any global CLI dependencies you want every machine to have.
5. Document secrets and credential restore steps for things like SSH keys, GitHub auth, cloud tokens, and app sign-ins.
6. Add macOS system preference setup for defaults like Finder, Dock, keyboard, screenshots, and input behavior.

Practical repo structure to grow toward:

- `Brewfile` for formulae and casks
- `mas` app manifest or a dedicated tracked section in bootstrap docs
- `zsh/`, `git/`, `config/`, and app-specific config directories
- `scripts/bootstrap.sh`, `scripts/install-apps.sh`, `scripts/uninstall.sh`, and a future `scripts/post-install.sh`
- `docs/manual-steps.md` for secrets, login steps, and machine-specific tasks

Automation guidelines for future phases:

- Fully automate package installs, symlinked configs, and repeatable macOS defaults
- Keep secrets, account logins, licenses, and other personal state as documented manual steps unless you later add a secure secret-management workflow
- Add validation steps after bootstrap, such as `brew doctor`, `mas list`, `gh auth status`, and spot checks for linked config files

## Notes

- v1 intentionally keeps the uninstall scope limited to Homebrew-managed software. It does not remove unrelated shell files, dotfiles, or user configuration.
- The first tracked formula is `jq` so the workflow stays simple and easy to validate.
- The tracked [zsh/.zshrc](/Users/blackpig/Code/Github/dotfiles/zsh/.zshrc) will source `~/.zshrc.local` when present, so each Mac can keep machine-specific zsh settings outside the repo.
- The tracked [zsh/.zprofile](/Users/blackpig/Code/Github/dotfiles/zsh/.zprofile) will source `~/.zprofile.local` when present, so each Mac can keep machine-specific login-shell settings outside the repo.

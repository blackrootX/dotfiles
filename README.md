# dotfiles

Migration helpers for bringing command-line tooling onto a new Mac.

The current setup is centered on Homebrew packages managed through a `Brewfile`. It already covers the core CLI layer for a new Mac and leaves room to keep expanding into `cask`, `mas`, secrets, and deeper config syncing.

## Requirements

- macOS
- `bash`
- Network access
- Administrator access for Homebrew installation

## Layout

- `scripts/bootstrap.sh`: install Homebrew if needed, then install tracked packages and shell config
- `scripts/install-apps.sh`: install tracked Mac App Store apps with `mas`
- `scripts/uninstall.sh`: remove tracked Homebrew formulae, then uninstall Homebrew
- `Brewfile`: source of truth for tracked Homebrew CLI packages
- `configs/ghostty/`: tracked Ghostty config directory applied to `~/.config/ghostty`
- `configs/starship/starship.toml`: tracked Starship prompt config applied to `~/.config/starship.toml`
- `configs/zsh/.zprofile`: tracked login-shell config applied to `~/.zprofile`
- `configs/zsh/.zshrc`: tracked zsh config applied to `~/.zshrc` during bootstrap
- `configs/zsh/.zsh_plugins.txt`: tracked Antidote plugin list applied to `~/.zsh_plugins.txt`

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
- Replaces any existing `~/.zprofile` with the tracked `configs/zsh/.zprofile`
- Links `~/.zprofile` to the tracked `configs/zsh/.zprofile`
- Replaces any existing `~/.zshrc` with the tracked `configs/zsh/.zshrc`
- Links `~/.zshrc` to the tracked `configs/zsh/.zshrc`
- Replaces any existing `~/.zsh_plugins.txt` with the tracked `configs/zsh/.zsh_plugins.txt`
- Links `~/.zsh_plugins.txt` to the tracked `configs/zsh/.zsh_plugins.txt`
- Replaces any existing `~/.config/starship.toml` with the tracked Starship config
- Replaces any existing `~/.config/ghostty` with the tracked Ghostty config directory
- Installs all packages declared in `Brewfile`
- Offers an interactive 1Password CLI sign-in checkpoint after package install, with a skip option for later setup
- Offers an interactive Spotify login checkpoint after 1Password sign-in when Spotify is installed

The uninstall script currently does the following:

- Verifies the host is macOS
- Cleans up the managed `~/.zprofile` symlink even if Homebrew is already absent
- Cleans up the managed `~/.zshrc` symlink even if Homebrew is already absent
- Cleans up the managed `~/.zsh_plugins.txt` symlink even if Homebrew is already absent
- Cleans up the managed `~/.config/starship.toml` symlink even if Homebrew is already absent
- Cleans up the managed `~/.config/ghostty` symlink even if Homebrew is already absent
- Uninstalls tracked formulae and casks declared in `Brewfile`
- Attempts to uninstall any remaining Homebrew formulae and casks
- Runs the official Homebrew uninstall script
- Removes legacy `*.pre-dotfiles-backup` files from older bootstrap runs when present

The app install script currently does the following:

- Verifies the host is macOS
- Requires Homebrew to already be installed
- Ensures `mas` is available
- Requires an active Mac App Store login
- Installs tracked App Store apps such as Amphetamine, WeChat, and Xcode

## Idempotency

- Running `./scripts/bootstrap.sh` multiple times is safe. Existing Homebrew installs and already-installed formulae are skipped.
- Running `./scripts/install-apps.sh` multiple times is safe. Already-installed App Store apps are skipped.
- Running `./scripts/uninstall.sh` on a machine without Homebrew exits successfully with a message.

## Roadmap

Suggested expansion order for this repo:

1. Add `brew cask` coverage for desktop apps that are not better handled by the Mac App Store.
2. Grow `mas` coverage for Mac App Store apps that should stay on Apple-managed install and update flows.
3. Track more shell, Git, terminal, and editor configs that should follow you to a new Mac.
4. Expand runtime and toolchain setup such as `mise`, Node, Python tooling, and any global CLI dependencies you still want standardized.
5. Document secrets and credential restore steps for things like SSH keys, GitHub auth, cloud tokens, app sign-ins, and future 1Password-backed setup.
6. Add macOS system preference setup for defaults like Finder, Dock, keyboard, screenshots, and input behavior.

Practical repo structure to grow toward:

- `Brewfile` for formulae and casks
- `mas` app manifest or a dedicated tracked section in bootstrap docs
- `configs/zsh/`, `git/`, `config/`, and app-specific config directories
- `scripts/bootstrap.sh`, `scripts/install-apps.sh`, `scripts/uninstall.sh`, and a future `scripts/post-install.sh`
- `docs/manual-steps.md` for secrets, login steps, and machine-specific tasks

Automation guidelines for future phases:

- Fully automate package installs, symlinked configs, and repeatable macOS defaults
- Keep secrets, account logins, licenses, and other personal state as documented manual steps unless you later add a secure secret-management workflow
- Add validation steps after bootstrap, such as `brew doctor`, `mas list`, `gh auth status`, and spot checks for linked config files

## Notes

- The current focus is the Homebrew-managed CLI layer plus the shell config needed to use it comfortably on a new Mac.
- The uninstall flow intentionally stays limited to Homebrew-managed software and the repo-managed shell artifacts it created. It does not remove unrelated personal files or user configuration.
- The tracked [configs/zsh/.zshrc](/Users/blackpig/Code/Github/dotfiles/configs/zsh/.zshrc) will source `~/.zshrc.local` when present, so each Mac can keep machine-specific zsh settings outside the repo.
- The tracked [configs/zsh/.zprofile](/Users/blackpig/Code/Github/dotfiles/configs/zsh/.zprofile) will source `~/.zprofile.local` when present, so each Mac can keep machine-specific login-shell settings outside the repo.

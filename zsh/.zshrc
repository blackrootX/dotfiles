export EZA_CONFIG_DIR="${HOME}/.config/eza"
export EZA_COLORS_THEME="dracula"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --no-user --group-directories-first'
  alias ll='eza -l --icons --no-user --group-directories-first'
  alias lln='eza -l --no-user --group-directories-first'
  alias la='eza -la --icons --no-user --group-directories-first'
  alias lt='eza --tree --icons --no-user'
fi

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v fd >/dev/null 2>&1 && command -v fzf >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="${FZF_DEFAULT_COMMAND}"
fi

for fzf_prefix in /opt/homebrew /usr/local; do
  if [[ -f "${fzf_prefix}/opt/fzf/shell/completion.zsh" ]]; then
    source "${fzf_prefix}/opt/fzf/shell/completion.zsh"
  fi

  if [[ -f "${fzf_prefix}/opt/fzf/shell/key-bindings.zsh" ]]; then
    source "${fzf_prefix}/opt/fzf/shell/key-bindings.zsh"
  fi
done

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

y() {
  if ! command -v yazi >/dev/null 2>&1; then
    printf 'yazi is not installed.\n' >&2
    return 1
  fi

  local tmp cwd
  tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
  command yazi "$@" --cwd-file="$tmp"
  IFS= read -r -d '' cwd < "$tmp"
  if [[ "${cwd}" != "${PWD}" && -d "${cwd}" ]]; then
    builtin cd -- "${cwd}"
  fi
  rm -f -- "$tmp"
}

if [[ -f "${HOME}/.zshrc.local" ]]; then
  source "${HOME}/.zshrc.local"
fi

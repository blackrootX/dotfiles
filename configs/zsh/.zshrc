export EZA_COLORS_THEME="dracula"
export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_INSTALL_CLEANUP=1

_antidote_load() {
  local antidote_script plugins_file bundle_file
  antidote_script=""
  plugins_file="${HOME}/.zsh_plugins.txt"
  bundle_file="${HOME}/.zsh_plugins.zsh"

  for antidote_prefix in /opt/homebrew /usr/local; do
    if [[ -f "${antidote_prefix}/share/antidote/antidote.zsh" ]]; then
      antidote_script="${antidote_prefix}/share/antidote/antidote.zsh"
      break
    fi
  done

  [[ -n "${antidote_script}" ]] || return 0
  [[ -f "${plugins_file}" ]] || return 0

  source "${antidote_script}"

  if [[ ! -f "${bundle_file}" || "${plugins_file}" -nt "${bundle_file}" ]]; then
    antidote bundle < "${plugins_file}" > "${bundle_file}"
  fi

  source "${bundle_file}"
}

_antidote_update() {
  local antidote_script
  antidote_script=""

  for antidote_prefix in /opt/homebrew /usr/local; do
    if [[ -f "${antidote_prefix}/share/antidote/antidote.zsh" ]]; then
      antidote_script="${antidote_prefix}/share/antidote/antidote.zsh"
      break
    fi
  done

  [[ -n "${antidote_script}" ]] || return 1

  source "${antidote_script}"
  antidote update
  rm -f -- "${HOME}/.zsh_plugins.zsh"
}

_antidote_load

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

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

alias oc="/opt/homebrew/bin/opencode"
alias cc="claude"
alias ccd="claude --allow-dangerously-skip-permissions"
alias uu="brew update && brew upgrade && mise upgrade && antidote update"

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

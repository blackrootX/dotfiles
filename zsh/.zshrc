export HOMEBREW_API_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles/api"
export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.tuna.tsinghua.edu.cn/homebrew-bottles"
export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git"
export HOMEBREW_INSTALL_FROM_API=1

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

if [[ -f "${HOME}/.zshrc.local" ]]; then
  source "${HOME}/.zshrc.local"
fi

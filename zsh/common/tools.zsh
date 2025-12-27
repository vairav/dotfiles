# Tool Integrations
# Shared across all frameworks

# Mise (runtime version manager)
if [[ -x /opt/homebrew/bin/mise ]]; then
  eval "$(/opt/homebrew/bin/mise activate zsh)"
elif [[ -x /usr/local/bin/mise ]]; then
  eval "$(/usr/local/bin/mise activate zsh)"
elif command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

# Zoxide (smart cd)
if command -v zoxide &>/dev/null; then
  export _ZO_DATA_DIR=$HOME/.config/zoxide
  eval "$(zoxide init --cmd cd zsh)"
fi

# Prompt (Starship or Oh My Posh)
if command -v starship &>/dev/null; then
  eval "$(starship init zsh)"
elif command -v oh-my-posh &>/dev/null; then
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(oh-my-posh init zsh --config $(brew --prefix oh-my-posh)/themes/catppuccin_mocha.omp.json)"
  else
    eval "$(oh-my-posh init zsh)"
  fi
fi

# Atuin (shell history)
if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh)"
fi

# fzf (fuzzy finder - for files, git, etc. History handled by atuin)
[[ -f $DOTFILES/zsh/common/fzf.zsh ]] && source $DOTFILES/zsh/common/fzf.zsh

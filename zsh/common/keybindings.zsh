# Keybindings Configuration
# Shared across all frameworks

# Vi mode
bindkey -v

# Remove path separator from WORDCHARS
WORDCHARS=${WORDCHARS//[\/]}

# Cmd+K (macOS) and Ctrl+Shift+K (Linux): clear the screen and scrollback.
# The terminal sends \e[9001~ (config/alacritty/configs/keys.toml,
# config/kitty/configs/keys.conf). Inside tmux, tmux takes it first
# (tmux/conf/keybindings.conf). This is the fallback when tmux is not running.
clear-screen-and-scrollback() {
  printf '\e[3J'
  zle clear-screen
}
zle -N clear-screen-and-scrollback
bindkey -M viins '\e[9001~' clear-screen-and-scrollback
bindkey -M vicmd '\e[9001~' clear-screen-and-scrollback

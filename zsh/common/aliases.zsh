# Aliases

# Editor
alias vi="nvim"
alias vim="nvim"
alias v='$EDITOR'
alias nvchad="NVIM_APPNAME=nvim/nvchad nvim"

# Common
alias c='clear'

# Modern replacements
command -v bat &>/dev/null && alias cat='bat'
# eza is a baseline package on every machine (core/server lists) - no fallbacks,
# so ls/ll/la behave identically everywhere
#
# `--icons=auto`, NOT a bare `--icons`. In current eza the flag takes an
# OPTIONAL value (always|auto|never), so a bare `--icons` immediately followed
# by a path swallows the path as its value and eza exits 2:
#     ls ~/.tmux/plugins  ->  error: invalid value '/Users/...' for '--icons'
# Bare `ls` worked, and so did `ls -la <path>` (the flag stops at the next
# `-`), so this only broke the bare `<alias> <path>` form - the most common one
# there is. It reads as an empty or missing directory rather than an error,
# which is exactly how it cost a wrong conclusion here: a check for TPM
# reported "never installed" for a directory that had been fully populated for
# three hours. Attaching the value with `=` removes the ambiguity entirely.
alias ls='eza --icons=auto'
alias ll='eza -al --icons=auto'
alias lt='eza -a --tree --level=1 --icons=auto'
alias la='eza -a --icons=auto'

# Power commands
if [[ "$OSTYPE" == "darwin"* ]]; then
  alias shutdown='sudo shutdown -h now'
  alias reboot='sudo reboot'
  alias logout='osascript -e "tell application \"System Events\" to log out"'
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
  alias shutdown='systemctl poweroff'
  alias reboot='systemctl reboot'
  alias wifi='nmtui'
  alias update-grub='sudo grub-mkconfig -o /boot/grub/grub.cfg'

  # Hyprland
  if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    alias lock='hyprlock'
    alias logout='hyprctl dispatch exit'
  # i3
  elif [[ -n "$I3SOCK" ]]; then
    alias logout='i3-msg exit'
  fi
fi

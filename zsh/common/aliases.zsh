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
if command -v eza &>/dev/null; then
  alias ls='eza --icons'
  alias ll='eza -al --icons'
  alias lt='eza -a --tree --level=1 --icons'
  alias la='eza -a --icons'
fi

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

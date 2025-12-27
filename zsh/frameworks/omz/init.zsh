# Oh My Zsh Framework Initialization
# Placeholder - configure when ready to use

# Installation:
#   sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

export ZSH="$HOME/.oh-my-zsh"

# Theme
ZSH_THEME="robbyrussell"

# Plugins
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Uncomment when oh-my-zsh is installed
# source $ZSH/oh-my-zsh.sh

echo "Oh My Zsh not configured yet. Install it first or switch to another framework."
echo "Set ZSH_FRAMEWORK=zim or ZSH_FRAMEWORK=plain in ~/.zshrc.local"

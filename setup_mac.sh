# Install zsh
brew update
brew upgrade

brew install zsh zsh-completions

# Check what is the current default shell
dscl . -read /Users/$USER UserShell

# Check if the brew zsh is installed properly
ls -la /usr/local/bin/zs*

# Set ZSH as the default shell
sudo dscl . -create /Users/$USER UserShell /usr/local/bin/zsh

# Confirm that the homebrew zsh is being used
dscl . -read /Users/$USER UserShell

# Setup Powerline fonts
git clone https://github.com/powerline/fonts.git --depth=1
# Install/Copy over fonts to the fonts folder in Mac OSX
cd fonts
./install.sh
# Remove the git cloned folder as it is not needed any more
cd ..
rm -rf fonts

# Install Powerline9k ZSH plugin
git clone https://github.com/bhilburn/powerlevel9k.git ~/.oh-my-zsh/custom/themes/powerlevel9k
# Change the theme in .zshrc to the one below:
# ZSH_THEME="powerlevel9k/powerlevel9k"

# Mac OSX related fixes

# Show User's library folder all the time
chflags nohidden ~/Library/

# Link Sublime executable to bin directory for temrinal access
ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl  # Sublime 3

# Git setup
ln -s ~/workspace/dotfiles/git/gitconfig .gitconfig

# Vim
export VIM_HOME=$HOME/workspace/dotfiles/vim
export EDITOR=vim

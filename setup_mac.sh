# Mac OSX related fixes

# Show User's library folder all the time
chflags nohidden ~/Library/

# Link Sublime executable to bin directory for temrinal access
ln -s /Applications/Sublime\ Text.app/Contents/SharedSupport/bin/subl /usr/local/bin/subl  # Sublime 3

# Install vim-plug to manage vim plugins
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Now you need to install all plugins within vim using vim-plug
# Launch vim, then type:
:PlugInstall

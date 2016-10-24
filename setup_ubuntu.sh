#!/bin/bash

# Download and install vim-plug plugin manager
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim

# Install all plugins using vim-plug from the .vimrc
echo "Installing plugins..."
vim +PlugInstall +qall

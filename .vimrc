" Disable automatic spell checking
"set nospell

" Disable automatic bracket closing feature
" let g:autoclose_on = 0

" Make Vim more useful
set nocompatible

" Enable line numbers
set number

" Highlight current line
set cursorline

" Make tabs as wide as two spaces
set tabstop=4
set shiftwidth=4
set expandtab

" Ignore case of searches
set ignorecase

" Highlight dynamically as pattern is typed
set incsearch

" Always show status line
set laststatus=2

" Disable error bells
set noerrorbells

" Don’t reset cursor to start of line when moving around.
set nostartofline

" Show the cursor position
set ruler

" Don’t show the intro message when starting Vim
set shortmess=atI

" Show the current mode
set showmode

" Show the filename in the window titlebar
set title

" Show the (partial) command as it’s being typed
set showcmd

" Start scrolling three lines before the horizontal window border
set scrolloff=3

" Enable per-directory .vimrc files and disable unsafe commands in them
set exrc
set secure

" Enable syntax highlighting
syntax on

" vim-plug - Plugin Manager
call plug#begin('~/.vim/plugged')

" NERD tree will be loaded on the first invocation of NERDTreeToggle command
Plug 'scrooloose/nerdtree', { 'on': 'NERDTreeToggle' }

" Racer plugin for Rust Language support
Plug 'phildawes/racer', { 'for': 'rust' }

" Rust syntax highlighting
Plug 'wting/rust.vim', { 'for': 'rust' }

call plug#end()

" Racer plugin setup
set hidden
let g:racer_cmd="/Users/vlaxman/.vim/plugged/racer/target/release/racer"
let $RUST_SRC_PATH="/Users/vlaxman/rustc-1.2.0/src"

" Special case end of file definitions for overriding certain entities
" Added to the of the file because the plugin's will override filetype
" association, which will not happen if we initialize it too soon

" Automatic commands
if has("autocmd")
    " Enable file type detection
    filetype on
    " Treat .json files as .js
    autocmd BufNewFile,BufRead *.json setfiletype json syntax=javascript
    " Treat .md files as Markdown
    autocmd BufNewFile,BufRead *.md setlocal filetype=markdown
	" Treat .rs files as Rust files
	autocmd BufNewFile,BufRead *.rs setlocal filetype=rust
endif

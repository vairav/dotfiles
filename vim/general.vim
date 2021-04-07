" general.vim

syntax on   " Enable syntax highlighting
" Use new regular expression engine and disable the old regular expression engine
set re=0
"set nospell    " Disable automatic spell checking
" let g:autoclose_on = 0    " Disable automatic bracket closing feature
set nocompatible    " Make Vim more useful
set nostartofline   " Don’t reset cursor to start of line when moving around.
set shortmess=atI   " Don’t show the intro message when starting Vim
set lazyredraw  " Redraw only when needed and not always

" Turn off search highlights
" nnoremap <leader><space> :nohlsearch<CR>

" Enable per-directory .vimrc files and disable unsafe commands in them
set exrc
set secure

" Use path '~/.vim' even on non-unix machine
set runtimepath+=~/.vim

set wildmenu " Enhance command-line completion
set wildignore=*.swp,*.swo,*.class  " Ignore when expanding wildcards
set history=256 " Number of things to remember in history
set clipboard=unnamed " Use the OS clipboard by default (on versions compiled with `+clipboard`)
set ttyfast  " Optimize for fast terminal connections
set tags=./tags;$HOME  " Walk directory tree upto $HOME looking for tags

" Don’t add empty newlines at the end of files
" set binary
" set noendofline
" Add empty newlines at the end of files
set endofline

set autochdir  " Automatically change window's cwd to file's dir
" Set path to viminfo
if !has('nvim')
  set viminfo='100,n$HOME/.viminfo
endif

" Set default shell to execute functions
"set shell=sh

"" Modeline
" Respect modeline in files
set modeline
set modelines=4

"" Python
" Figure out the system Python for Neovim.
"if exists("$VIRTUAL_ENV")
"  let g:python3_host_prog=substitute(system('which -a python3 | head -n2 | tail -n1'), '\n', '', 'g')
"else
"  let g:python3_host_prog=substitute(system('which python3'), '\n', '', 'g')
"endif

""" Auto Commands {{{
  if has('autocmd')
    " Auto reload vimrc
    " augroup reload_vimrc
    "   autocmd!
    "   autocmd BufWritePost $MYVIMRC,*.vim
    "     \ source $MYVIMRC |
    "     \ echo 'Reloaded VIM Configurations'
    " augroup END
    " Restore cursor position when opening file
    augroup restore_cursor
      autocmd!
      autocmd BufReadPost *
        \ if line("'\"") > 1 && line("'\"") <= line("$") |
        \   exe "normal! g`\"" |
        \ endif
    augroup END
  endif
""" }}}

""" Folding {{{
  " Turn on folding
  set foldenable
  " Make folding indent sensitive
  set foldmethod=indent
  " Don't autofold anything
  set foldlevel=99
  " Don't open folds when search into them
  set foldopen-=search
  " Don't open folds when undo stuff
  set foldopen-=undo
""" }}}

""" Backup & Swap {{{
  " No backup & swap files
  set noswapfile
  set nobackup
  " Centralize backups, swapfiles and undo history
  " set backupdir=~/.vim/backups
  " set directory=~/.vim/swaps
  " Maintain undo history between sessions
  set undofile
  " Set maximum number of changes that can be undone
  set undolevels=100
  " Change directory to save undo history
  if has('persistent_undo') && !has('nvim')
    set undodir=~/.vim/cache
    if !isdirectory(&undodir)
      " Create directory
      call mkdir(&undodir, 'p')
    endif
  endif
  " Don’t create backups when editing files in certain directories
  set backupskip=/tmp/*
""" }}}

""" Encoding {{{
  set encoding=utf-8
  set fileencodings=utf-8
""" }}}

""" Formatting {{{
  " Set the default tabstop
  set tabstop=2
  set softtabstop=2
  " Set the default shift width for indents
  set shiftwidth=2
  " Make tabs into spaces (set by tabstop)
  set expandtab
  " Smarter tab levels
  set smarttab
  " Copy indent from current line when starting a new line
  set autoindent
  " Do smart autoindenting when starting a new line
  set smartindent
""" }}}

""" Grep {{{
  if executable('rg')
    " Use rg(ripgrep)
    set grepprg=rg\ --no-heading\ --vimgrep
  elseif executable('pt')
    " Use pt(The Platinum Searcher)
    set grepprg=pt\ --nocolor\ --nogroup\ --column
  elseif executable('ag')
    " Use ag(The Silver Searcher)
    set grepprg=ag\ --vimgrep
  elseif executable('ack')
    set grepprg=ack\ -H\ --nocolor\ --nogroup
  endif
  " Set format for vimgrep
  set grepformat=%f:%l:%c:%m
""" }}}

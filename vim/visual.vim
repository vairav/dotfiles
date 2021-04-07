" visual.vim

" Enable syntax highlighting
syntax on

" Enable line numbers
set number

" Enable relative number for line
" (Constantly computing the relative numbers is expensive)
"set relativenumber

" Always show signcolumns
set signcolumn=yes

" Show ruler
set ruler

" Always show tab pannel
set showtabline=2

" Show the (partial) command as it’s being typed
set showcmd

" Highlight matching brackets, i.e. [], {}, ()
set showmatch

" Bracket blinking
set matchtime=5

" Show the current mode
set showmode
" Hide the current mode
"set noshowmode

" Mark 80th column with a highlight color
if exists('+colorcolumn')
  set colorcolumn=80
  highlight ColorColumn ctermbg=gray
endif

" Highlight current line
set cursorline

" Show cursorline for active window only
augroup highlight_active_window
  autocmd!
  autocmd BufEnter * setlocal cursorline
  autocmd BufLeave * setlocal nocursorline
augroup END

" Show the filename in the window's titlebar
set title

" Disable visual bell from interrupting us
set novisualbell

" Disable error bells and stay silent
set noerrorbells

" Start scrolling when below number of lines are above/below the cursor
set scrolloff=3

" Native customized statusline, if airline is not available
set statusline=%1*%{winnr()}\ %*%<\ %f\ %h%m%r%=%l,%c%V\ (%P)

" Always show status line
set laststatus=2

" No conceal
set conceallevel=0

" Use a block cursor in normal mode, i-beam cursor in insertmode
if empty($TMUX)
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
else
  let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
  let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
endif

" Enable if the terminal supports true colors
if has('termguicolors')
  set termguicolors
endif
if has('nvim')
  set inccommand=split
endif

""" Search {{{
  " Highlight the search matches
  set hlsearch
  " Ignore case of searches
  set ignorecase
  " Be sensitive when there's a capital letter
  set smartcase
  " Highlight dynamically as pattern is typed, i.e. start searching as soon
  " as characters are being typed
  set incsearch
""" }}}

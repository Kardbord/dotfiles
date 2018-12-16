filetype plugin indent on

" show existing tab with 4 spaces width
set tabstop=4

" when indenting with '>', use 4 spaces width
set shiftwidth=4

" on pressing tab, insert 4 spaces
set expandtab

set background=dark

autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

syntax on

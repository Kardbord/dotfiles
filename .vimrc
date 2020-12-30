filetype plugin indent on

" show existing tab with 2 spaces width
set tabstop=2

" when indenting with '>', use 2 spaces width
set shiftwidth=2

" on pressing tab, insert 2 spaces
set expandtab

set background=dark

set number

autocmd FileType * setlocal formatoptions-=c formatoptions-=r formatoptions-=o

syntax on

set foldmethod=syntax

nmap <F5> i<C-R>=strftime("%Y-%m-%d %a %I:%M %p")<CR><Esc>
imap <F5> <C-R>=strftime("%Y-%m-%d %a %I:%M %p")<CR>

nmap <F6> i<C-R>=strftime("**************** %Y-%m-%d %a %I:%M %p ****************")<CR><Esc>
imap <F6> <C-R>=strftime("**************** %Y-%m-%d %a %I:%M %p ****************")<CR>

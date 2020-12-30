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

" Don't screw up folds when inserting text that might affect them, until
" leaving insert mode. Foldmethod is local to the window. Protect against
" screwing up folding when switching between windows.
autocmd InsertEnter * if !exists('w:last_fdm') | let w:last_fdm=&foldmethod | setlocal foldmethod=manual | endif
autocmd InsertLeave,WinLeave * if exists('w:last_fdm') | let &l:foldmethod=w:last_fdm | unlet w:last_fdm | endif

nmap <F5> i<C-R>=strftime("%Y-%m-%d %a %I:%M %p")<CR><Esc>
imap <F5> <C-R>=strftime("%Y-%m-%d %a %I:%M %p")<CR>

nmap <F6> i<C-R>=strftime("**************** %Y-%m-%d %a %I:%M %p ****************")<CR><Esc>
imap <F6> <C-R>=strftime("**************** %Y-%m-%d %a %I:%M %p ****************")<CR>

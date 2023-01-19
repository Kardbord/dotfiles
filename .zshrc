export PATH="/usr/local/sbin:$PATH"

PROMPT="%F{green}[%f%F{red}%n%f%F{cyan}@%f%F{magenta}%m%f %F{cyan}%t%f %F{yellow}%d%f%F{green}]%f "

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'A

alias ll='ls -alhF'
set -o vi

if [ -d "$HOME/.cargo" -a -f "$HOME/.cargo/env" ]; then
  source "$HOME/.cargo/env"
fi

#if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
#    exec tmux
#fi

if command -v neofetch &> /dev/null; then
  neofetch
fi

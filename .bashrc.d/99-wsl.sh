[[ -n "${_WSL}" ]] || return

alias exit='find /tmp -type f -atime +10 -delete && exit'

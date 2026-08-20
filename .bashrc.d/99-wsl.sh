[[ -n "${_WSL}" ]] || return

alias exit='find /tmp -type f -atime +10 -delete && exit'

eval "$(dbus-launch --sh-syntax 2>/dev/null)"

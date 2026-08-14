[[ "${_OS_ID}" = opensuse-* ]] || return

alias update='sudo sh -c "zypper up -y && zypper dup -y && flatpak --system update -y --no-static-deltas" && flatpak --user update -y --no-static-deltas'

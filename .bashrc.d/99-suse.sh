[[ "${OS_ID}" = opensuse-* ]] || return

alias update='sudo sh -c "zypper up -y && zypper dup -y && flatpak --user update && flatpak --system update"'

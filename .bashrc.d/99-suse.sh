[[ "${OS_ID}" = opensuse-* ]] || return

alias update='sudo sh -c "zypper up -y && zypper dup -y && flatpak --system update -y" && flatpak --user update -y'

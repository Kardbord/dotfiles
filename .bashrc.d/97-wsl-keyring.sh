[[ -n "${_WSL:-}" ]] || return

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  if command -v dbus-launch &>/dev/null; then
    eval "$(dbus-launch --sh-syntax)" &>/dev/null
  fi
fi

if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]] && \
  command -v gnome-keyring-daemon &>/dev/null; then
  gnome-keyring-daemon --start --components=secrets &>/dev/null
fi

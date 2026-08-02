[[ -n "${_WSL:-}" ]] || return

if [[ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  if command -v dbus-launch &>/dev/null; then
    eval "$(dbus-launch --sh-syntax 2>/dev/null)"
  else
    echo "[dbus] dbus is not installed (see https://www.freedesktop.org/wiki/Software/dbus/)" >&2
  fi
fi

if [[ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
  if command -v gnome-keyring-daemon &>/dev/null; then
    gnome-keyring-daemon --start --components=secrets &>/dev/null
  else
    echo "[wsl-secrets] gnome-keyring-daemon is not installed (see https://gitlab.gnome.org/GNOME/gnome-keyring/)" >&2
  fi
fi

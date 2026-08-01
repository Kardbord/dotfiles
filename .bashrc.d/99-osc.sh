_OSC_REQUIRED_ENV=(
  "OSC_USERNAME=personal/opensuse/user"
  "OSC_PASSWORD=personal/opensuse/pass"
)

_osc_ensure_deps() {
  if ! command -v osc &>/dev/null; then
    echo "[osc] osc is not installed (see https://en.opensuse.org/openSUSE:OSC)" >&2
    return 1
  fi

  if ! _secrets_are_set "${_OSC_REQUIRED_ENV[@]}"; then
    echo "[osc] missing required secrets ${_OSC_REQUIRED_ENV[*]}" >&2
    return 1
  fi
}

osc() {
  _osc_ensure_deps || return 1
  local -a secrets
  mapfile -t secrets <<< "$(_secrets_from_pass_or_env "${_OSC_REQUIRED_ENV[@]}")"
  env "${secrets[@]}" osc "${@}"
}

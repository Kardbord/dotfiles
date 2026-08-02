if ! command -v wslinfo &>/dev/null; then
  return
fi

_WSL=1
_WSL_VERSION="$(wslinfo --version)"

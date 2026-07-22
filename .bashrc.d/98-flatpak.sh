_REQUIRED_FLATPAKS=(
  "org.freedesktop.Sdk"
)

_REQUIRED_FLATPAK_SDK_EXTS=(
  "org.freedesktop.Sdk.Extension.dotnet"
  "org.freedesktop.Sdk.Extension.dotnet10"
  "org.freedesktop.Sdk.Extension.golang"
  "org.freedesktop.Sdk.Extension.llvm22"
  "org.freedesktop.Sdk.Extension.mingw-w64"
  "org.freedesktop.Sdk.Extension.node26"
  "org.freedesktop.Sdk.Extension.openjdk25"
  "org.freedesktop.Sdk.Extension.rust-stable"
  "org.freedesktop.Sdk.Extension.texlive"
)

# Useful for flatpaks that use the FLATPAK_ENABLE_SDK_EXT environment variable, such as neovim.
_FLATPAK_ENABLE_SDK_EXT="$(IFS=,; echo "${_REQUIRED_FLATPAK_SDK_EXTS[*]/org.freedesktop.Sdk.Extension./}")"

_ensure_flatpak() {
  if ! command -v flatpak &>/dev/null; then
    echo "[sandbox] flatpak is not installed (see https://flatpak.org)" >&2
    return 1
  fi

  for dep in "${_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak (see https://flathub.org/en/apps/${dep})" >&2
      return 1
    fi
  done

  for dep in "${_REQUIRED_FLATPAK_SDK_EXTS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak (see https://flathub.org/en/apps/${dep})" >&2
      return 1
    fi
  done
}

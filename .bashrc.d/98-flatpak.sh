declare -A _REQUIRED_FLATPAK_REMOTES=(
  [https://dl.flathub.org/repo]=https://dl.flathub.org/repo/flathub.flatpakrepo
  [oci+https://kardbord.github.io/Boxes]=https://kardbord.github.io/Boxes/kardbord-boxes.flatpakrepo
)

_REQUIRED_FLATPAKS=(
  "org.freedesktop.Sdk"
  "io.github.kardbord.Sdk"
  "io.github.kardbord.Platform"
  "io.github.kardbord.fd"
  "io.github.kardbord.fzf"
  "io.github.kardbord.neovim"
  "io.github.kardbord.opencode"
  "io.github.kardbord.ripgrep"
  "io.github.kardbord.sk"
  "io.github.kardbord.tool.lua"
  "io.github.kardbord.tool.ruby4"
  "io.github.kardbord.tool.uv"
  "io.github.kardbord.treesitter-cli"
  "io.github.kardbord.viu"
)

_REQUIRED_FLATPAK_SDK_EXTS=(
  "org.freedesktop.Sdk.Extension.dotnet10"
  "org.freedesktop.Sdk.Extension.golang"
  "org.freedesktop.Sdk.Extension.llvm22"
  "org.freedesktop.Sdk.Extension.mingw-w64"
  "org.freedesktop.Sdk.Extension.node26"
  "org.freedesktop.Sdk.Extension.openjdk"
  "org.freedesktop.Sdk.Extension.rust-stable"
  "org.freedesktop.Sdk.Extension.typescript"
  "org.freedesktop.Sdk.Extension.bazel"
)

# Useful for flatpaks that use the FLATPAK_ENABLE_SDK_EXT environment variable, such as neovim.
_FLATPAK_ENABLE_SDK_EXT="$(
  IFS=,
  echo "${_REQUIRED_FLATPAK_SDK_EXTS[*]/org.freedesktop.Sdk.Extension./}"
)"

_ensure_flatpak() {
  if ! command -v flatpak &>/dev/null; then
    echo "[sandbox] flatpak is not installed (see https://flatpak.org)" >&2
    return 1
  fi

  for remote in "${!_REQUIRED_FLATPAK_REMOTES[@]}"; do
    if ! flatpak remotes --columns=url | grep -q "${remote}"; then
      echo "[sandbox] flatpak is missing a required remote: ${remote}" >&2
      echo "[sandbox] Install with:" >&2
      echo "  flatpak remote-add --user --if-not-exists <name> ${_REQUIRED_FLATPAK_REMOTES[${remote}]}"
      return 1
    fi
  done

  for dep in "${_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak." >&2
      return 1
    fi
  done

  for dep in "${_REQUIRED_FLATPAK_SDK_EXTS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak." >&2
      return 1
    fi
  done
}

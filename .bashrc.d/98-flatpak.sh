declare -A _REQUIRED_FLATPAK_REMOTES=(
  [https://dl.flathub.org/repo]=https://dl.flathub.org/repo/flathub.flatpakrepo
  [oci+https://Kardbord.github.io/Boxes]=https://kardbord.github.io/Boxes/kardbord-boxes.flatpakrepo
)

_REQUIRED_FLATPAKS=(
  "io.github.kardbord.dev"
  "org.freedesktop.Sdk"
  "org.freedesktop.Sdk.Extension.bazel"
  "org.freedesktop.Sdk.Extension.dotnet10"
  "org.freedesktop.Sdk.Extension.golang"
  "org.freedesktop.Sdk.Extension.llvm22"
  "org.freedesktop.Sdk.Extension.mingw-w64"
  "org.freedesktop.Sdk.Extension.node26"
  "org.freedesktop.Sdk.Extension.openjdk"
  "org.freedesktop.Sdk.Extension.rust-nightly"
  "org.freedesktop.Sdk.Extension.typescript"
)

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
}

_KB_DEV_TOOLS_COMMON_ARGS=(
  --filesystem=/tmp
  --filesystem=/var/tmp
  --socket=wayland
  --socket=fallback-x11
  --share=ipc
)

# Generic runner for any tools in the io.github.kardbord.dev flatpak.
kb-dev-tools() {
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    io.github.kardbord.dev \
    "$@"
}

# Generic runner for any tools in the io.github.kardbord.dev flatpak.
# Includes network access
kb-dev-tools-networked() {
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    --share=network
    io.github.kardbord.dev \
    "$@"
}

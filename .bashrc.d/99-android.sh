# ------------------------------------------------------ #
#  Android SDK (extensionless)                           #
# ------------------------------------------------------ #
# Unlike fvm (a single self-contained binary), the       #
# Android SDK is a sdkmanager-managed *mutable* tree     #
# (platform-tools, platforms, build-tools, NDK,          #
# emulator, system images) that varies per project and   #
# API level — a poor fit for an immutable flatpak tool   #
# extension. So nothing is packaged: the only host-side  #
# step is unpacking the official cmdline-tools zip into  #
# the XDG cache. Every execution — sdkmanager,           #
# avdmanager, adb, emulator, and the flutter/gradle      #
# builds they drive — runs inside a kardbord.dev         #
# sandbox against the xdg-cache/android-sdk, android,    #
# and gradle mounts granted in 98-flatpak.sh, whose      #
# --env lines mirror the exports below into sandboxes    #
# (the in-sandbox tools see no host shell env, so the    #
# values must be kept in sync with this file).           #
#                                                        #
# Java is not needed on the host: the openjdk SDK        #
# extension inherited by io.github.kardbord.dev provides #
# it in-sandbox (activate-kardbord-env sources           #
# /usr/lib/sdk/*/enable.sh).                             #
#                                                        #
# One-time setup (host shell; the zip is only ever       #
# unpacked, never executed):                             #
#   android-sdk-install <commandlinetools-linux-*.zip>   #
#   yes | sdkmanager --licenses                          #
#   sdkmanager "platform-tools" "platforms;android-34" \ #
#     "build-tools;34.0.0" "emulator" \                  #
#     "system-images;android-34;google_apis;x86_64"      #
#     (plus the NDK version your Flutter/AGP wants)      #
#                                                        #
# Host-shell flutter/dart invocations go through the fvm #
# wrapper (99-fvm.sh), e.g. `fvm flutter run` — already  #
# sandboxed with the same common args.                   #
#                                                        #
# Emulator notes (WSL): requires Windows 11 with         #
# `[wsl2] nestedVirtualization=true` in .wslconfig and   #
# /dev/kvm group access (see /etc/wsl.conf boot command) #
# and `--device=kvm`, which needs flatpak >= 1.15.7.     #
# With WSLg providing the display, `-gpu                 #
# swiftshader_indirect` works without any host GPU.      #
# ------------------------------------------------------ #

# Android SDK settings. ANDROID_HOME selects the sdkmanager root;
# ANDROID_USER_HOME holds AVDs, adb keys, and other per-user state;
# GRADLE_USER_HOME redirects the Gradle daemon/plugin cache (otherwise
# android builds write ~/.gradle, which sandboxes cannot see). Each must
# match the value passed to sandboxes in 98-flatpak.sh.
export ANDROID_HOME="${_KB_XDG_CACHE}/android-sdk"
export ANDROID_USER_HOME="${_KB_XDG_CACHE}/android"
export ANDROID_AVD_HOME="${ANDROID_USER_HOME}/avd"
export GRADLE_USER_HOME="${_KB_XDG_CACHE}/gradle"

# One-time helper: unpack a downloaded official cmdline-tools zip into
# $ANDROID_HOME/cmdline-tools/latest (the nested `latest` directory is what
# sdkmanager/avdmanager expect; getting it wrong is the classic setup bug).
# The zip is unpacked only — nothing in it is executed on the host.
android-sdk-install() {
  if [ "$#" -ne 1 ]; then
    echo "usage: android-sdk-install <commandlinetools-linux-*.zip>" >&2
    return 2
  fi
  local zip="$1"
  local latest="${ANDROID_HOME}/cmdline-tools/latest"
  if [ -e "${latest}/bin/sdkmanager" ]; then
    echo "cmdline-tools already installed at ${latest}" >&2
    return 1
  fi
  if [ ! -f "${zip}" ]; then
    echo "not a file: ${zip}" >&2
    return 1
  fi
  local tmp
  tmp="$(mktemp -d)" || return 1
  if ! unzip -q "${zip}" -d "${tmp}"; then
    rm -rf "${tmp}"
    echo "failed to unzip ${zip} (is unzip installed?)" >&2
    return 1
  fi
  mkdir -p "${ANDROID_HOME}/cmdline-tools"
  mv "${tmp}/cmdline-tools" "${latest}"
  rm -rf "${tmp}"
  echo "Installed cmdline-tools to ${latest}"
}

sdkmanager() {
  _ensure_flatpak || return 1
  local bin="${ANDROID_HOME}/cmdline-tools/latest/bin/sdkmanager"
  if [ ! -x "${bin}" ]; then
    echo "sdkmanager not found at ${bin}" >&2
    echo "Run: android-sdk-install <commandlinetools-linux-*.zip>" >&2
    return 1
  fi

  # Network: sdkmanager downloads SDK components and accepts licenses.
  # No PWD grant needed: it only writes into ANDROID_HOME/ANDROID_USER_HOME.
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --share=network \
    io.github.kardbord.dev "${bin}" "$@"
}

avdmanager() {
  _ensure_flatpak || return 1
  local bin="${ANDROID_HOME}/cmdline-tools/latest/bin/avdmanager"
  if [ ! -x "${bin}" ]; then
    echo "avdmanager not found at ${bin}" >&2
    echo "Run: android-sdk-install <commandlinetools-linux-*.zip>" >&2
    return 1
  fi

  # No network or PWD grant needed: avdmanager writes AVDs into
  # ANDROID_AVD_HOME (granted via the xdg-cache/android mount).
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    io.github.kardbord.dev "${bin}" "$@"
}

adb() {
  _ensure_flatpak || return 1
  local bin="${ANDROID_HOME}/platform-tools/adb"
  if [ ! -x "${bin}" ]; then
    echo "adb not found at ${bin}" >&2
    echo 'Run: sdkmanager "platform-tools"' >&2
    return 1
  fi

  # Network: adb server connections (Wi-Fi devices via `adb connect`, and
  # the loopback adb server itself). The adb server persists on the host
  # network namespace across invocations, so it is not restarted per call.
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --share=network \
    io.github.kardbord.dev "${bin}" "$@"
}

emulator() {
  _ensure_flatpak || return 1
  local bin="${ANDROID_HOME}/emulator/emulator"
  if [ ! -x "${bin}" ]; then
    echo "emulator not found at ${bin}" >&2
    echo 'Run: sdkmanager "emulator" "system-images;android-34;google_apis;x86_64"' >&2
    return 1
  fi

  # --device=kvm: hardware acceleration (see the WSL notes in the header).
  # Network: emulator talks to adb and, with google_apis images, Google
  # services. Display comes from the wayland/x11 sockets in the common args.
  # AVD data and adb keys live in ANDROID_AVD_HOME/ANDROID_USER_HOME
  # (granted via the xdg-cache/android mount).
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --device=kvm \
    --share=network \
    io.github.kardbord.dev "${bin}" "$@"
}

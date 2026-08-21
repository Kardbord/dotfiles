# ------------------------------------------------------ #
#                                          __            #
#   ____  ____  ___  ____  _________  ____/ /__          #
#  / __ \/ __ \/ _ \/ __ \/ ___/ __ \/ __  / _ \         #
# / /_/ / /_/ /  __/ / / / /__/ /_/ / /_/ /  __/         #
# \____/ .___/\___/_/ /_/\___/\____/\__,_/\___/          #
#     /_/                                                #
# ------------------------------------------------------ #
# Opencode executes LLM-generated code — read, write,    #
# run, install packages — all on the model's say-so.     #
# One prompt injection is all it takes. I highly         #
# recommend installing opencode via flatpak on any       #
# system that supports it. Flatpak sandboxes the         #
# process, containing the blast radius if the model      #
# goes rogue. The config below works either way.         #
# See docs/SECURITY.md#sandboxing                        #
# ------------------------------------------------------ #

_OPENCODE_REQUIRED_FLATPAKS=(
  "io.github.kardbord.Sdk"
  "io.github.kardbord.Platform"
  "io.github.kardbord.opencode"
)

_OPENCODE_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
  "HUGGINGFACE_API_KEY=personal/huggingface/api-key"
  "GITHUB_PERSONAL_ACCESS_TOKEN=personal/github/ro-pat"
  "COMPOSIO_API_KEY=personal/composio/api-key"
)

_OPENCODE_FLATPAK_COMMON_ARGS=(
  "--env=FLATPAK_ENABLE_SDK_EXT=${_FLATPAK_ENABLE_SDK_EXT}"
  "--filesystem=xdg-config/opencode"
)

_opencode_flatpak_run_cmd() {
  local sdk_ext setup='' exts
  IFS=',' read -ra exts <<<"${_FLATPAK_ENABLE_SDK_EXT}"
  for sdk_ext in "${exts[@]}"; do
    setup+="[[ -f /usr/lib/sdk/${sdk_ext}/enable.sh ]] && . /usr/lib/sdk/${sdk_ext}/enable.sh; "
  done
  setup+="activate-kardbord-env "
  flatpak run \
    "${_OPENCODE_FLATPAK_COMMON_ARGS[@]}" \
    --nofilesystem=host \
    --filesystem="${PWD}" \
    --command=sh \
    io.github.kardbord.opencode \
    -c "${setup}${*}"
}

_opencode_flatpak_ensure_deps() {
  _ensure_flatpak || return 1

  for dep in "${_OPENCODE_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak." >&2
      return 1
    fi
  done

  if ! _secrets_are_set "${_OPENCODE_REQUIRED_ENV[@]}"; then
    echo "[opencode] Warning! Opencode plugin functionality may be limited without all of these secrets: ${_OPENCODE_REQUIRED_ENV[*]}" >&2
    sleep 2
  fi
}

alias opencode-nosandbox='opencode_nosandbox'
opencode_nosandbox() {
  _opencode_flatpak_ensure_deps || return 1
  _run_with_secrets "${_OPENCODE_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_OPENCODE_FLATPAK_COMMON_ARGS[@]}" \
    --filesystem=host \
    io.github.kardbord.opencode "$@"
}

opencode() {
  _opencode_flatpak_ensure_deps || return 1
  _run_with_secrets "${_OPENCODE_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_OPENCODE_FLATPAK_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    io.github.kardbord.opencode "$@"
}

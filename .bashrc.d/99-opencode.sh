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


if ! command -v opencode &>/dev/null; then
  return
fi

_OPENCODE_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
)

_OPENCODE_OPTIONAL_ENV=(
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
)

_opencode_flatpak_ensure_deps() {
  _ensure_flatpak || return 1

  if ! flatpak info "ai.opencode.opencode" &>/dev/null; then
    echo "[sandbox] opencode is not installed via flatpak (see https://flathub.org/en/apps/ai.opencode.opencode)" >&2
    return 1
  fi

  if ! _secrets_are_set "${_OPENCODE_REQUIRED_ENV[@]}"; then
    echo "Opencode requires the following secrets in as environment variables (lhs) or gopass entries: ${_OPENCODE_REQUIRED_ENV[*]}" >&2
    return 1
  fi

  if ! _secrets_are_set "${_OPENCODE_OPTIONAL_ENV[@]}"; then
    echo "Opencode optional secrets not detected: ${_OPENCODE_OPTIONAL_ENV[*]}" >&2
  fi
}

opencode() {
  _opencode_flatpak_ensure_deps || return 1
  local secrets
  secrets=$(_secrets_from_pass_or_env "${_OPENCODE_REQUIRED_ENV[@]}" "${_OPENCODE_OPTIONAL_ENV[@]}")
  flatpak run \
    "${secrets[@]/#/--env=}" \
    --env=FLATPAK_ENABLE_SDK_EXT="${_FLATPAK_ENABLE_SDK_EXT}" \
    --nofilesystem=home \
    --nofilesystem=/media \
    --nofilesystem=/run/media \
    --nofilesystem=/mnt \
    --filesystem="${PWD}"
    ai.opencode.opencode "${@}"
}

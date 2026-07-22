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

if [[ -d "${HOME}/.opencode/bin" ]]; then
  export PATH="${HOME}/.opencode/bin:$PATH"
fi

_OPENCODE_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
)

_OPENCODE_OPTIONAL_ENV=(
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
)

opencode() {
  if ! _secrets_are_set "${_OPENCODE_REQUIRED_ENV[@]}"; then
    echo "Opencode requires the following secrets in as environment variables (lhs) or gopass entries: ${_OPENCODE_REQUIRED_ENV[*]}" >&2
    return 1
  fi

  if ! _secrets_are_set "${_OPENCODE_OPTIONAL_ENV[@]}"; then
    echo "Optional secrets not detected: ${_OPENCODE_OPTIONAL_ENV[*]}" >&2
  fi

  $(_secrets_from_pass_or_env "${_OPENCODE_REQUIRED_ENV[@]}" "${_OPENCODE_OPTIONAL_ENV[@]}") opencode
}

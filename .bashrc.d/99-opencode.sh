# TODO: Add ascii art
# TODO: Recommend flatpak installation for sandboxing


if ! command -v opencode &>/dev/null; then
  return
fi

if [[ -d "${HOME}/.opencode/bin" ]]; then
  export PATH="${HOME}/.opencode/bin:$PATH"
fi

_OPENCODE_REQUIRED_ENV=(
  "OPENROUTER_API_KEY="
)

_OPENCODE_OPTIONAL_ENV=(
  "OPENAI_API_KEY="
  "ANTHROPIC_API_KEY="
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

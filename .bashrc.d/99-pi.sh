# ------------------------------------------------------ #
#                                  _/                    #
#                       _/_/_/                           #
#                      _/    _/  _/                      #
#                     _/    _/  _/                       #
#                    _/_/_/    _/                        #
#                   _/                                   #
#                  _/                                    #
# ------------------------------------------------------ #
# Pi executes LLM-generated code — read, write, run,     #
# install packages — all on the model's say-so.          #
# One prompt injection is all it takes. By running it in #
# flatpak, we sandbox the process, containing the blast  #
# radius if the model goes rogue or a plugin is          #
# compromised. See docs/SECURITY.md#sandboxing           #
# ------------------------------------------------------ #

export PI_CODING_AGENT_DIR="${HOME}/.config/pi"

_PI_REQUIRED_FLATPAKS=(
  "io.github.kardbord.dev"
  "io.github.kardbord.tool.pi"
)

_PI_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
  "HUGGINGFACE_API_KEY=personal/huggingface/api-key"
  "GITHUB_PERSONAL_ACCESS_TOKEN=personal/github/ro-pat"
  "COMPOSIO_API_KEY=personal/composio/api-key"
)

_pi_flatpak_ensure_deps() {
  _ensure_flatpak || return 1

  for dep in "${_PI_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak." >&2
      return 1
    fi
  done

  if ! _secrets_are_set "${_PI_REQUIRED_ENV[@]}"; then
    echo "[pi] Warning! Pi plugin functionality may be limited without all of these secrets: ${_PI_REQUIRED_ENV[*]}" >&2
    sleep 2
  fi
}

alias pi-nosandbox='pi_nosandbox'
pi_nosandbox() {
  _pi_flatpak_ensure_deps || return 1
  _run_with_secrets "${_PI_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem=host \
    --filesystem=xdg-config/pi \
    --share=network \
    --env=GIT_AUTHOR_NAME="Tanner Kvarfordt" \
    --env=GIT_COMMITTER_NAME="Tanner Kvarfordt" \
    --env=GIT_AUTHOR_EMAIL="tanner.kvarfordt@proton.me" \
    --env=GIT_COMMITTER_EMAIL="tanner.kvarfordt@proton.me" \
    io.github.kardbord.dev pi "$@"
}

pi() {
  _pi_flatpak_ensure_deps || return 1
  _run_with_secrets "${_PI_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    --filesystem=xdg-config/pi \
    --share=network \
    --env=GIT_AUTHOR_NAME="Tanner Kvarfordt" \
    --env=GIT_COMMITTER_NAME="Tanner Kvarfordt" \
    --env=GIT_AUTHOR_EMAIL="tanner.kvarfordt@proton.me" \
    --env=GIT_COMMITTER_EMAIL="tanner.kvarfordt@proton.me" \
    io.github.kardbord.dev pi "$@"
}

eval "$(npx --quiet -y pi-completion bash)"

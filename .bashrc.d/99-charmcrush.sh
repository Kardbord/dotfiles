# ------------------------------------------------------ #
#                                _                       #
#             ___ _ __ _   _ ___| |__                    #
#            / __| '__| | | / __| '_ \                   #
#           | (__| |  | |_| \__ \ | | |                  #
#            \___|_|   \__,_|___/_| |_|                  #
# ------------------------------------------------------ #
# Crush executes LLM-generated code — read, write,       #
# run, install packages — all on the model's say-so.     #
# One prompt injection is all it takes. By running it in #
# flatpak, we sandbox the process, containing the blast  #
# radius if the model goes rogue or a plugin is          #
# compromised. See docs/SECURITY.md#sandboxing           #
# ------------------------------------------------------ #

_CHARMCRUSH_REQUIRED_FLATPAKS=(
  "io.github.kardbord.dev"
  "io.github.kardbord.tool.charmcrush"
)

_CHARMCRUSH_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
  "HF_TOKEN=personal/huggingface/api-key"
  "GITHUB_PERSONAL_ACCESS_TOKEN=personal/github/ro-pat"
)

_charmcrush_flatpak_ensure_deps() {
  _ensure_flatpak || return 1

  for dep in "${_CHARMCRUSH_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak." >&2
      return 1
    fi
  done

  if ! _secrets_are_set "${_CHARMCRUSH_REQUIRED_ENV[@]}"; then
    echo "[charmcrush] Warning! charmcrush plugin functionality may be limited without all of these secrets: ${_CHARMCRUSH_REQUIRED_ENV[*]}" >&2
    sleep 2
  fi
}

alias crush-nosandbox='charmcrush_nosandbox'
crush_nosandbox() {
  _charmcrush_flatpak_ensure_deps || return 1
  _run_with_secrets "${_CHARMCRUSH_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem=host \
    --filesystem=xdg-config/crush \
    --share=network \
    --env=GIT_AUTHOR_NAME="Tanner Kvarfordt" \
    --env=GIT_COMMITTER_NAME="Tanner Kvarfordt" \
    --env=GIT_AUTHOR_EMAIL="tanner.kvarfordt@proton.me" \
    --env=GIT_COMMITTER_EMAIL="tanner.kvarfordt@proton.me" \
    io.github.kardbord.dev charmcrush "$@"
}

crush() {
  _charmcrush_flatpak_ensure_deps || return 1
  _run_with_secrets "${_CHARMCRUSH_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    --filesystem=xdg-config/crush \
    --share=network \
    --env=GIT_AUTHOR_NAME="Tanner Kvarfordt" \
    --env=GIT_COMMITTER_NAME="Tanner Kvarfordt" \
    --env=GIT_AUTHOR_EMAIL="tanner.kvarfordt@proton.me" \
    --env=GIT_COMMITTER_EMAIL="tanner.kvarfordt@proton.me" \
    io.github.kardbord.dev charmcrush "$@"
}

eval "$(crush completion bash)"

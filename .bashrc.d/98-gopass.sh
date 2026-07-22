# TODO: Add ascii art
# TODO: Add blurb explaining gopass and why it's necessary
_GOPASS_READY=

# Retrieve a secret from gopass, falling back
# to the environment variable if it is set.
# Takes at least one argument in the format
#   ENVVAR1=gopass/path1 ENVVAR2=gopass/path2
# and outputs secret variables in the format
#   ENVVAR1=secret1 ENVVAR2=secret2
_secrets_from_pass_or_env() {
  [[ -z "${*}" ]] && return 1
  for arg in "${@}"; do
    local envvar="${arg%%=*}"
    local gppath="${arg#*=}"
    local secret
    if [[ -n "${_GOPASS_READY}" ]]; then
      secret="$(gopass show "${gppath}" 2>/dev/null || printenv "${envvar}")"
    else
      secret="$(printenv "${envvar}")"
    fi
    echo "${envvar}=${secret}"
  done
}

# Check if the secrets are set.
# Takes at least one argument in the format
#   ENVVAR1=gopass/path1 ENVVAR2=gopass/path2
# Returns 0 if asked-for secrets are set, 1
# otherwise.
_secrets_are_set() {
  [[ -z "${*}" ]] && return 0
  for arg in "${@}"; do
    local envvar="${arg%%=*}"
    local gppath="${arg#*=}"
    local secret
    if [[ -n "${_GOPASS_READY}" ]]; then
      secret="$(gopass show "${gppath}" 2>/dev/null || printenv "${envvar}")"
    else
      secret="$(printenv "${envvar}")"
    fi
    [[ -z "${secret}" ]] && return 1
  done
  return 0
}

if ! command -v gopass &>/dev/null; then
  echo "[secrets] gopass is not installed (see https://www.gopass.pw/)" >&2
  return
fi

if ! command -v age &>/dev/null; then
  echo "[secrets] age is not installed (see https://github.com/FiloSottile/age)" >&2
  return
fi

if ! gopass list &>/dev/null 2>&1; then
  echo "[secrets] gopass store not initialized. Run: gopass setup --crypto age --remote ... --create ... (see ~/.bashrc.d/*-gopass.sh)" >&2
  return
fi
_GOPASS_READY=1

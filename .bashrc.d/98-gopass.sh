# ------------------------------------------------------ #
#    ____ _____  ____  ____ ___________                  #
#   / __ `/ __ \/ __ \/ __ `/ ___/ ___/                  #
#  / /_/ / /_/ / /_/ / /_/ (__  |__  )                   #
#  \__, /\____/ .___/\__,_/____/____/                    #
# /____/     /_/                                         #
# ------------------------------------------------------ #
# Secrets management layer: gopass + age backend.        #
# Secrets are encrypted at rest, scoped per-tool,        #
# and never live in plaintext config. Retrieved          #
# at runtime, falling back to env vars if gopass         #
# is unavailable.                                        #
# See docs/SECURITY.md#secrets-management                #
# ------------------------------------------------------ #

export GOPASS_AGE_STDIN_PASSPHRASE=1

_GOPASS_READY=

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

# Run a command with secrets injected into its environment.
#
# Usage: _run_with_secrets ENVVAR1=gopass/path1 ENVVAR2=gopass/path2 -- command args...
#
# Secrets are resolved from gopass (falling back to env vars) and
# passed via shell assignment syntax (VAR=value command), not `env`,
# so credentials never appear in argv (/proc/cmdline).
# Values are escaped with printf '%q' before eval, preventing injection.
_run_with_secrets() {
  local -a env_parts=()
  local arg key gppath secret

  while (( $# )); do
    arg="$1"; shift
    [[ "$arg" == "--" ]] && break

    key="${arg%%=*}"
    gppath="${arg#*=}"

    [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && {
      echo "[_run_with_secrets] invalid env var name: '$key'" >&2
      return 1
    }

    if [[ -n "${_GOPASS_READY}" ]]; then
      secret="$(gopass show "${gppath}" 2>/dev/null || printenv "${key}")"
    else
      secret="$(printenv "${key}")"
    fi

    [[ -z "${secret}" ]] && {
      echo "[_run_with_secrets] could not resolve secret for '${key}'" >&2
      return 1
    }

    env_parts+=("${key}=$(printf '%q' "${secret}")")
  done

  (( $# )) || { echo "[_run_with_secrets] no command specified after --" >&2; return 1; }

  local -a cmd_parts=()
  for arg in "$@"; do
    cmd_parts+=("$(printf '%q' "${arg}")")
  done

  eval "${env_parts[*]} ${cmd_parts[*]}"
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

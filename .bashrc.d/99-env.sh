# Non-secret environment variables that apply globally to the user.
# Secrets should be managed with gopass (see docs/SECURITY.md#secrets-management).
if [ -f "${HOME}/.bash_env" ]; then
  source "${HOME}/.bash_env"
fi

if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  export TMUX_TMPDIR="${HOME}/.local/run/"
  mkdir -p "${TMUX_TMPDIR}"
  exec tmux -u
fi

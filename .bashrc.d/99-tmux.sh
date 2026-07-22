if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  export TMUX_TMPDIR="${HOME}/.local/run/"
  mkdir -p "${TMUX_TMPDIR}"
  exec tmux -u
  # Only reached if exec fails
  echo "[tmux] failed to start, continuing without tmux" >&2
fi

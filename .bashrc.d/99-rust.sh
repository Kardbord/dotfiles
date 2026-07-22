if [[ -f "$HOME/.cargo/env" ]]; then
  source "$HOME/.cargo/env"
fi
if [[ -d "${HOME}/.cargo/bin" ]]; then
  export PATH="${PATH}:${HOME}/.cargo/bin"
fi

if [[ -d "${HOME}/bin" && -O "${HOME}/bin" ]]; then
  export PATH="${HOME}/bin:${PATH}"
fi

if [[ -d "${HOME}/.local/bin" && -O "${HOME}/.local/bin" ]]; then
  export PATH="${HOME}/.local/bin:$PATH"
fi

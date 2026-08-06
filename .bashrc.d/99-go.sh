if [[ -d "/usr/local/go/bin" ]]; then
  export PATH="${PATH}:/usr/local/go/bin"
fi

if [[ -d "${GOBIN}" ]]; then
  export PATH="${PATH}:${GOBIN}"
fi

if [[ -d "${GOPATH:-${HOME}/go}/bin" ]]; then
  export PATH="${PATH}:${GOPATH:-${HOME}/go}/bin"
fi


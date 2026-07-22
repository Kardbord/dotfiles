if ls --color=auto &>/dev/null 2>&1; then
  alias ll='ls -alFh --color=auto'
else
  alias ll='ls -alFhG'
fi

if command -v rg &>/dev/null; then
  alias rg='rg -g "!.git/*" --hidden -n'
  alias rgi='rg -i -g "!.git/*" --hidden -n'
fi

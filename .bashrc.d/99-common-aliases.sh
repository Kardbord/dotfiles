alias ll='ls -alh'

if command -v rg &>/dev/null; then
  alias rg='rg -g "!.git/*" --hidden -n'
  alias rgi='rg -iglob "!.git/*" --hidden -ni'
fi

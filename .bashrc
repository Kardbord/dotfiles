# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
  *i*) ;;
  *) return;;
esac

if [[ -d "${HOME}/.bashrc.d" ]]; then
  for cfg in "${HOME}/.bashrc.d"/*.sh; do
    [[ -r "${cfg}" ]] && source "${cfg}"
  done
fi

set -o vi

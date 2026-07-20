alias vim='nvim'
alias neovim='nvim'
alias ll='ls -alh'
alias rg='rg -g "!.git/*" --hidden -n'
alias rgi='rg -iglob "!.git/*" --hidden -ni'
#alias clip='xclip -selection clipboard -i <'
#alias update='sudo zypper update -y && sudo zypper dup -y && sudo flatpak update -y && flatpak update --user -y'
#alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'

nvim() {
  if command -v firejail &>/dev/null; then
    if [[ $(uname -r) =~ WSL ]]; then
      container=lxc firejail "$(which nvim)" "${@}"
    else
      firejail "$(which nvim)" "${@}"
    fi
  else
    echo "[sandbox] firejail not found, cannot sandbox neovim" 1>&2
    sleep 1
    "$(which nvim)" "${@}"
  fi
}

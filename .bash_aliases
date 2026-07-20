alias ll='ls -alh'
alias rg='rg -g "!.git/*" --hidden -n'
alias rgi='rg -iglob "!.git/*" --hidden -ni'
#alias clip='xclip -selection clipboard -i <'
#alias update='sudo zypper update -y && sudo zypper dup -y && flatpak --user update -y && flatpak update -y'
#alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'

# Flatpak'd Neovim aliases
alias vim-unsafe='nvim-unsafe'
alias neovim-unsafe='nvim-unsafe'
alias nvim-unsafe='flatpak run \
  --filesystem=xdg-config/nvim \
  io.neovim.nvim'
alias vim='nvim'
alias neovim='nvim'
alias nvim='flatpak run \
  --nofilesystem=host \
  --filesystem="${PWD}" \
  --filesystem=xdg-config/nvim \
  io.neovim.nvim'

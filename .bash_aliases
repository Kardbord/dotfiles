alias ll='ls -alh'
alias rg='rg -g "!.git/*" --hidden -n'
alias rgi='rg -iglob "!.git/*" --hidden -ni'
#alias clip='xclip -selection clipboard -i <'
#alias update='sudo zypper update -y && sudo zypper dup -y && flatpak --user update -y && flatpak update -y'
#alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'

# ----- Flatpak'd Neovim Setup ----- #
_FLATPAK_ENABLE_SDK_EXT='node26,golang,rust,openjdk25'
_NVIM_FLATPAK_XDG_DATA_HOME="${HOME}/.var/app/io.neovim.nvim/data"
_NVIM_FLATPAK_DFLT_PATH='/app/bin:/usr/bin'
_NVIM_FLATPAK_PATH="${_NVIM_FLATPAK_DFLT_PATH}:${_NVIM_FLATPAK_XDG_DATA_HOME}/tree-sitter/bin"

_nvim_flatpak_run_cmd() {
  flatpak run \
    --nofilesystem=host \
    --filesystem=xdg-config/nvim \
    --env=PATH="${_NVIM_FLATPAK_PATH}" \
    --env=FLATPAK_ENABLE_SDK_EXT="${_FLATPAK_ENABLE_SDK_EXT}" \
    --command=sh \
    io.neovim.nvim \
    -c "${*}"
}

_nvim_flatpak_ensure_deps() {
  # Check host dependencies
  if ! command -v flatpak &>/dev/null; then
    echo "[sandbox] flatpak is not installed (see https://flatpak.org)" >&2
    return 1
  fi
  if ! flatpak info io.neovim.nvim &>/dev/null; then
    echo "[sandbox] neovim is not installed via flatpak (see https://flathub.org/en/apps/io.neovim.nvim)" >&2
    return 1
  fi
  # TODO: check for SDKs

  # Check sandbox dependencies
  if ! _nvim_flatpak_run_cmd 'command -v tree-sitter' &>/dev/null; then
    echo "[sandbox] bootstrapping nvim sandbox with tree-sitter-cli..."
    _nvim_flatpak_run_cmd ". /usr/lib/sdk/node26/enable.sh && npm install -g --prefix='${_NVIM_FLATPAK_XDG_DATA_HOME}/tree-sitter' tree-sitter-cli"
  fi
}

alias vim-host='nvim_host'
alias neovim-host='nvim_host'
alias nvim-host='nvim_host'
nvim_host() {
  # Run neovim with default sandboxing.
  _nvim_flatpak_ensure_deps || return "${?}"
  flatpak run \
    --env=PATH="${_NVIM_FLATPAK_PATH}" \
    --env=FLATPAK_ENABLE_SDK_EXT="${_FLATPAK_ENABLE_SDK_EXT}" \
    --filesystem=xdg-config/nvim \
    io.neovim.nvim "${@}"
}

alias vim='nvim'
alias neovim='nvim'
nvim(){
  # Run neovim with extra sandboxing.
  _nvim_flatpak_ensure_deps || return "${?}"
  flatpak run \
    --env=PATH="${_NVIM_FLATPAK_PATH}" \
    --env=FLATPAK_ENABLE_SDK_EXT="${_FLATPAK_ENABLE_SDK_EXT}" \
    --nofilesystem=host \
    --filesystem="${PWD}" \
    --filesystem=xdg-config/nvim \
    io.neovim.nvim "${@}"
}

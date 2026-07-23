# ------------------------------------------------------ #
#             ____  ___  ____ _   __(_)___ ___           #
#            / __ \/ _ \/ __ \ | / / / __ `__ \          #
#           / / / /  __/ /_/ / |/ / / / / / / /          #
#          /_/ /_/\___/\____/|___/_/_/ /_/ /_/           #
# ------------------------------------------------------ #
# Neovim's greatest strength is also its greatest        #
# weakness: pluggability. Plugins provide incredible     #
# utility, but are extremely vulnerable to supply chain  #
# compromise, especially in this day and age of AI. For  #
# that reason, I highly encourage managing the nvim      #
# installation via flatpak on any system that supports   #
# it. Flatpak apps run in a sandbox, which significantly #
# reduces the blast radius of any compromised tools.     #
# This configuration reflects that recommendation, but   #
# I did try to take care that none of the neovim config  #
# present elsewhere in my dotfiles project relies on     #
# running in a flatpak sandbox.                          #
# ------------------------------------------------------ #

_NVIM_FLATPAK_XDG_DATA_HOME="${HOME}/.var/app/io.neovim.nvim/data"
_NVIM_FLATPAK_DFLT_PATH='/app/bin:/usr/bin'
_NVIM_FLATPAK_PATH="${_NVIM_FLATPAK_DFLT_PATH}:${_NVIM_FLATPAK_XDG_DATA_HOME}/tree-sitter/bin"
_NVIM_REQUIRED_FLATPAKS=(
  "io.neovim.nvim"
)

_NVIM_FLATPAK_COMMON_ARGS=(
  "--env=PATH=${_NVIM_FLATPAK_PATH}"
  "--env=FLATPAK_ENABLE_SDK_EXT=${_FLATPAK_ENABLE_SDK_EXT}"
  "--filesystem=xdg-config/nvim"
  "--filesystem=xdg-config/opencode"
)

_NVIM_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
  "HUGGINGFACE_API_KEY=personal/huggingface/api-key"
)

_nvim_flatpak_run_cmd() {
  flatpak run \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    --nofilesystem=host \
    --command=sh \
    io.neovim.nvim \
    -c "${*}"
}

_nvim_flatpak_ensure_deps() {
  _ensure_flatpak || return 1

  for dep in "${_NVIM_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak (see https://flathub.org/en/apps/${dep})" >&2
      return 1
    fi
  done

  if ! _nvim_flatpak_run_cmd 'command -v tree-sitter' &>/dev/null; then
    echo "[sandbox] bootstrapping nvim sandbox with tree-sitter-cli..."
    _nvim_flatpak_run_cmd ". /usr/lib/sdk/node26/enable.sh && npm install -g --prefix='${_NVIM_FLATPAK_XDG_DATA_HOME}/tree-sitter' tree-sitter-cli"
  fi

  if ! _secrets_are_set "${_NVIM_REQUIRED_ENV[@]}"; then
    echo "[nvim] Warning! Neovim plugin functionality may be limited without all of these secrets: ${_NVIM_REQUIRED_ENV[*]}" >&2
    sleep 2
  fi
}

alias vim-nosandbox='nvim_nosandbox'
alias neovim-nosandbox='nvim_nosandbox'
alias nvim-nosandbox='nvim_nosandbox'
nvim_nosandbox() {
  _nvim_flatpak_ensure_deps || return 1
  mapfile -t secrets <<< "$(_secrets_from_pass_or_env "${_NVIM_REQUIRED_ENV[@]}")"
  # Run neovim with default sandboxing.
  flatpak run \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    "${secrets[@]/#/--env=}" \
    io.neovim.nvim "${@}"
}

alias vim='nvim'
alias neovim='nvim'
nvim(){
  _nvim_flatpak_ensure_deps || return 1
  mapfile -t secrets <<< "$(_secrets_from_pass_or_env "${_NVIM_REQUIRED_ENV[@]}")"
  # Run neovim with extra sandboxing.
  flatpak run \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    "${secrets[@]/#/--env=}" \
    --nofilesystem=host \
    --filesystem="${PWD}" \
    io.neovim.nvim "${@}"
}

alias avante='nvim -c "lua vim.defer_fn(function()require(\"avante.api\").zen_mode()end, 100)"'


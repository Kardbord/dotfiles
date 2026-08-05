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
  "GITHUB_PERSONAL_ACCESS_TOKEN=personal/github/ro-pat"
  "COMPOSIO_API_KEY=personal/composio/api-key"
)

_nvim_flatpak_run_cmd() {
  local sdk_ext setup='' exts
  IFS=',' read -ra exts <<< "${_FLATPAK_ENABLE_SDK_EXT}"
  for sdk_ext in "${exts[@]}"; do
    setup+="[[ -f /usr/lib/sdk/${sdk_ext}/enable.sh ]] && . /usr/lib/sdk/${sdk_ext}/enable.sh; "
  done
  flatpak run \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    --nofilesystem=host \
    --filesystem="${PWD}" \
    --command=sh \
    io.neovim.nvim \
    -c "${setup}${*}"
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
    _nvim_flatpak_run_cmd "npm install -g --prefix='${_NVIM_FLATPAK_XDG_DATA_HOME}/tree-sitter' tree-sitter-cli"
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
  _run_with_secrets "${_NVIM_REQUIRED_ENV[@]}" -- \
    flatpak run \
      "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
      io.neovim.nvim "$@"
}

alias vim='nvim'
alias neovim='nvim'
nvim() {
  _nvim_flatpak_ensure_deps || return 1
  _run_with_secrets "${_NVIM_REQUIRED_ENV[@]}" -- \
    flatpak run \
      "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
      --nofilesystem=host \
      --filesystem="${PWD}" \
      io.neovim.nvim "$@"
}

# ------------------------------------------------------ #
#                                          __            #
#   ____  ____  ___  ____  _________  ____/ /__          #
#  / __ \/ __ \/ _ \/ __ \/ ___/ __ \/ __  / _ \         #
# / /_/ / /_/ /  __/ / / / /__/ /_/ / /_/ /  __/         #
# \____/ .___/\___/_/ /_/\___/\____/\__,_/\___/          #
#     /_/                                                #
# ------------------------------------------------------ #
# Opencode executes LLM-generated code — read, write,    #
# run, install packages — all on the model's say-so.     #
# One prompt injection is all it takes. I highly         #
# recommend installing opencode via flatpak on any       #
# system that supports it. Flatpak sandboxes the         #
# process, containing the blast radius if the model      #
# goes rogue. The config below works either way.         #
# See docs/SECURITY.md#sandboxing                        #
# ------------------------------------------------------ #
# TODO: figure out a better solution for sandboxing opencode
opencode() {
  _nvim_flatpak_ensure_deps || return 1
  # Kind of jank, but as of this writing the opencode
  # flatpak only includes the electron app and not the
  # TUI, which is all I care about. So for now, we launch
  # opencode out of the nvim flatpak since it has to run
  # opencode anyway for the CodeCompanion plugin.
  _run_with_secrets "${_NVIM_REQUIRED_ENV[@]}" -- \
    _nvim_flatpak_run_cmd "npx --yes opencode-ai ${*}"
}

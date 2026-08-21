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

_NVIM_REQUIRED_FLATPAKS=(
  "io.github.kardbord.Sdk"
  "io.github.kardbord.Platform"
  "io.github.kardbord.fd"
  "io.github.kardbord.fzf"
  "io.github.kardbord.neovim"
  "io.github.kardbord.opencode"
  "io.github.kardbord.ripgrep"
  "io.github.kardbord.sk"
  "io.github.kardbord.tool.lua"
  "io.github.kardbord.tool.ruby4"
  "io.github.kardbord.tool.uv"
  "io.github.kardbord.treesitter-cli"
  "io.github.kardbord.viu"
)

_NVIM_FLATPAK_COMMON_ARGS=(
  "--env=FLATPAK_ENABLE_SDK_EXT=${_FLATPAK_ENABLE_SDK_EXT}"
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
  IFS=',' read -ra exts <<<"${_FLATPAK_ENABLE_SDK_EXT}"
  for sdk_ext in "${exts[@]}"; do
    setup+="[[ -f /usr/lib/sdk/${sdk_ext}/enable.sh ]] && . /usr/lib/sdk/${sdk_ext}/enable.sh; "
  done
  setup+="activate-kardbord-env "
  flatpak run \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    --nofilesystem=host \
    --filesystem="${PWD}" \
    --command=sh \
    io.github.kardbord.neovim \
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
    --filesystem=host \
    io.github.kardbord.neovim "$@"
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
    io.github.kardbord.neovim "$@"
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
    _nvim_flatpak_run_cmd "opencode ${*}"
}

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
  "io.github.kardbord.dev"
  "io.github.kardbord.tool.actionlint"
  "io.github.kardbord.tool.clipboard"
  "io.github.kardbord.tool.fd"
  "io.github.kardbord.tool.fzf"
  "io.github.kardbord.tool.git"
  "io.github.kardbord.tool.lua"
  "io.github.kardbord.tool.neovim"
  "io.github.kardbord.tool.opencode"
  "io.github.kardbord.tool.ripgrep"
  "io.github.kardbord.tool.ruby4"
  "io.github.kardbord.tool.sk"
  "io.github.kardbord.tool.treesitter-cli"
  "io.github.kardbord.tool.uv"
  "io.github.kardbord.tool.viu"
)

_NVIM_FLATPAK_COMMON_ARGS=(
  "--filesystem=xdg-config/opencode"
  "--filesystem=xdg-config/nvim"
)

_NVIM_REQUIRED_ENV=(
  "OPENROUTER_API_KEY=personal/openrouter/api-key"
  "OPENAI_API_KEY=personal/openai/api-key"
  "ANTHROPIC_API_KEY=personal/anthropic/api-key"
  "HUGGINGFACE_API_KEY=personal/huggingface/api-key"
  "GITHUB_PERSONAL_ACCESS_TOKEN=personal/github/ro-pat"
  "COMPOSIO_API_KEY=personal/composio/api-key"
)

_nvim_flatpak_ensure_deps() {
  _ensure_flatpak || return 1

  for dep in "${_NVIM_REQUIRED_FLATPAKS[@]}"; do
    if ! flatpak info "${dep}" &>/dev/null; then
      echo "[sandbox] ${dep} is not installed via flatpak." >&2
      return 1
    fi
  done

  if ! _secrets_are_set "${_NVIM_REQUIRED_ENV[@]}"; then
    echo "[nvim] Warning! Neovim plugin functionality may be limited without all of these secrets: ${_NVIM_REQUIRED_ENV[*]}" >&2
    echo "[nvim] Sleeping to display warning..."
    sleep 5
  fi
}

alias vim-nosandbox='nvim_nosandbox'
alias neovim-nosandbox='nvim_nosandbox'
alias nvim-nosandbox='nvim_nosandbox'
nvim_nosandbox() {
  _nvim_flatpak_ensure_deps || return 1
  _run_with_secrets "${_NVIM_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    --filesystem=host \
    --share=network \
    io.github.kardbord.dev nvim "$@"
}

alias vim='nvim'
alias neovim='nvim'
nvim() {
  _nvim_flatpak_ensure_deps || return 1
  _run_with_secrets "${_NVIM_REQUIRED_ENV[@]}" -- \
    flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    "${_NVIM_FLATPAK_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    --share=network \
    io.github.kardbord.dev nvim "$@"
}

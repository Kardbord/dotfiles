# ------------------------------------------------------ #
#  Flutter Version Manager                               #
# ------------------------------------------------------ #
# All Dart/Flutter installations are managed by fvm,     #
# configured entirely via the environment variables      #
# below (fvm's config file is not used).                 #
#                                                        #
# fvm itself is never installed natively: the only       #
# distribution is the io.github.kardbord.tool.fvm        #
# flatpak extension. This wrapper shadows any host fvm   #
# so that every fvm invocation — host shell or inside a  #
# kardbord.dev sandbox (:terminal in nvim/pi) — runs the #
# same tool against the same cache. See 98-flatpak.sh    #
# for the fvm/pub filesystem grants and the --env lines  #
# that mirror these variables into sandboxes (the        #
# in-sandbox fvm does not see host shell env, so the     #
# values must be kept in sync with this file).           #
# ------------------------------------------------------ #

# fvm settings (replaces fvm's config file entirely). FVM_CACHE_PATH also
# selects the cache's project registry; FVM_GIT_CACHE_PATH is the shared git
# reference cache used when cloning flutter versions.
export FVM_CACHE_PATH="${_KB_XDG_CACHE}/fvm"
export FVM_GIT_CACHE_PATH="${_KB_XDG_CACHE}/fvm_git"

# Dart's pub cache: dart has no config-file option for this, only the PUB_CACHE
# environment variable. Keep it under the XDG cache so flatpak sandboxes can
# scope-grant it (see 98-flatpak.sh). Must match the value passed to sandboxes.
export PUB_CACHE="${_KB_XDG_CACHE}/pub"

fvm() {
  _ensure_flatpak || return 1

  # PWD: `fvm use` writes .fvm/ into the project.
  # Network: fvm downloads SDK versions and clones the flutter repo.
  # PUB_CACHE and the fvm/pub mounts arrive via the common args.
  flatpak run \
    "${_KB_DEV_TOOLS_COMMON_ARGS[@]}" \
    --filesystem="${PWD}" \
    --share=network \
    io.github.kardbord.dev fvm "$@"
}

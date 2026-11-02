# 05-mise.zsh — tool version manager
#
# mise is the only tool version manager on this machine. Which tools exist
# and which version each one is pinned to lives in
# ~/.config/mise/config.toml, which is stowed from mise/ in this repo.
#
# `mise activate zsh` puts mise's shims directory at the front of PATH and
# installs the hook that re-resolves the versions when the working
# directory changes. The shims are not appended by hand here: the
# activation script already exports them, and a second copy would only
# make PATH longer.
if (( $+commands[mise] )); then
  eval "$(mise activate zsh)"
fi

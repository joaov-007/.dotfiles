# 05-mise.zsh — tool version manager
#
# mise replaces the old asdf setup; its shims are added to PATH by
# `mise activate`, so there is no separate shims directory to append.
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

if command -v batman &>/dev/null; then
  eval "$(batman --export-env)"
fi

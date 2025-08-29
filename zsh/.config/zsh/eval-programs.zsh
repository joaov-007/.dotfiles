if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh)"
fi


if command -v fzf &>/dev/null; then
  eval "$(fzf --zsh)"
fi

if command -v zoxide &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

if command -v batman &>/dev/null; then
  eval "$(batman --export-env)"
fi

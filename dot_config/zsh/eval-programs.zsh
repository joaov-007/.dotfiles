if command -v atuin &>/dev/null; then
  eval "$(atuin init zsh)"
fi


if command -v atuin &>/dev/null; then
  eval "$(fzf --zsh)"
fi

if command -v atuin &>/dev/null; then
  eval "$(zoxide init zsh)"
fi

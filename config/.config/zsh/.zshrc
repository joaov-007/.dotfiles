# ~/.config/zsh/.zshrc
# Entry point. Sourced by zsh on every interactive shell.
# Everything else lives in this directory; see README.md.

# Config root — set first so the sourced files can rely on it.
: ${ZDOTDIR:=$HOME/.config/zsh}

# Keep plugin/completion caches next to the config instead of in $HOME.
: ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_DATA_HOME:=$HOME/.local/share}

# Source every NN-*.zsh here in name order. The NN- prefixes define load
# order, which matters: options before history (they interact), completion
# before the plugins (fzf-tab and zoxide both hook into it), and the prompt
# after everything else (pure owns PROMPT).
for _zsh_conf in "$ZDOTDIR"/[0-9][0-9]-*.zsh; do
  [[ -r $_zsh_conf ]] && source "$_zsh_conf"
done
unset _zsh_conf

# 60-keys.zsh — keybindings
#
# One clean set, in emacs mode. Nothing here is inherited from the older
# config, and no key is bound that another component already owns: Tab
# belongs to fzf-tab, Ctrl-R belongs to atuin.
#
# Nothing is bound to a bare modifier either, because the terminal may
# intercept it — Ctrl-S and Ctrl-Q are left to the tty (NO_FLOW_CONTROL).

# ── History search by prefix ────────────────────────────────
# Type "git " then Up/Down walks only the git commands you ran before.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search

# ── Accepting the ghost suggestion ─────────────────────────
# At the end of the buffer, forward-char accepts the whole suggestion.
# Ctrl+Right takes one word at a time; Ctrl+Left gives words back.
bindkey '^[[C'    forward-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '\e[1;5C' forward-word      # terminals that send ESC-1;5C

# ── Editing ────────────────────────────────────────────────
# Ctrl+X Ctrl+E opens the current line in $EDITOR.
autoload -Uz edit-line-with-editor
zle -N edit-line-with-editor
bindkey '^Xe' edit-line-with-editor

bindkey '\e.'    insert-last-word   # Alt+. repeats the last argument
bindkey '\e[3;3~' kill-word        # Alt+Delete

# ── History search ─────────────────────────────────────────
# Two widgets want Ctrl-R: atuin, which reaches the history of every
# machine synced with it, and fzf's own history picker. atuin wins,
# because it is the one that knows about the other machines; fzf keeps
# Ctrl-T and Alt-C.
#
# Rebound here because fzf is loaded in 40-plugins.zsh, after atuin
# (20-history.zsh).
if (( $+commands[atuin] )); then
  # Bound in the active keymap (main), not in "emacs" or "viins".
  #
  # zsh makes "viins" an alias for "main", so `bindkey -M viins` writes
  # into the same map and its vi-insert widget would win. atuin ships a
  # plain `atuin-search` widget that picks the movement keys itself, and
  # that is the one its own emacs binding uses.
  bindkey '^r' atuin-search
fi

# ── Shift-Tab ──────────────────────────────────────────────
# fzf-tab uses Shift-Tab to cycle the completion group. Without fzf-tab
# there is no group to cycle, so fall back to the standard expansion.
if (( ! $+functions[fzf-tab-complete] )); then
  bindkey '^[[Z' expand-or-complete
fi

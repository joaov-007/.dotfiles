# 40-plugins.zsh — integrations with system tools
#
# zinit (35-zinit.zsh) handles the zsh plugins. This file wires up the
# binaries that come from pacman. Nothing here installs anything: every
# block is a no-op when its package is missing.

# ── fzf shell integration ───────────────────────────────────
# Ctrl-R history, Ctrl-T files, Alt-C directory jump.
#
# Loaded after fzf-tab on purpose. fzf's integration binds Tab to its own
# `fzf-completion` widget, but that widget falls through to
# $fzf_default_completion — whatever Tab was bound to beforehand — unless
# a trigger character is typed. Setting it explicitly below makes the
# result independent of load order.
if (( $+commands[fzf] )); then
  eval "$(fzf --zsh 2>/dev/null)"
  (( $+functions[fzf-tab-complete] )) && fzf_default_completion=fzf-tab-complete
fi

# ── fzf-tab styles ──────────────────────────────────────────
# fzf-tab sets a few zstyles of its own when it loads, so these have to
# come after it.
if (( $+functions[fzf-tab-complete] )); then
  # Left/right arrows jump between completion groups.
  zstyle ':fzf-tab:*' switch-group '<' '>'

  # Custom flags. fzf-tab does not follow FZF_DEFAULT_OPTS on its own.
  zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' single-group color header

  # Preview a directory as a listing, a file with its contents.
  zstyle ':fzf-tab:complete:cd:*'             fzf-preview 'eza -1 --color=always $realpath 2>/dev/null'
  zstyle ':fzf-tab:complete:z:*'              fzf-preview 'eza -1 --color=always $realpath 2>/dev/null'
  zstyle ':fzf-tab:complete:__zoxide_cd:*'    fzf-preview 'eza -1 --color=always $realpath 2>/dev/null'
  zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff --color=always $word | delta'

  # No preview for options.
  zstyle ':fzf-tab:complete:*:options' fzf-preview ''

  zstyle ':fzf-tab:complete:*:*:argument-rest' fzf-preview '
    if [[ -d $realpath ]]; then
      eza --tree --color=always --level=3 "$realpath" 2>/dev/null
    elif [[ -f $realpath ]]; then
      if grep -qI . "$realpath" 2>/dev/null; then
        bat -p --color=always "$realpath" 2>/dev/null
      else
        echo "Size: $(stat -c %s "$realpath" 2>/dev/null) bytes"
      fi
    fi'
fi

# ── zoxide: jump to frecent directories ─────────────────────
# `z foo` to jump, `zi` for the interactive picker.
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd cd 2>/dev/null)"
  # A function, not an alias: zsh expands aliases before completion, so an
  # alias would bypass the compdef below. Reuse zoxide's own completer,
  # which offers local directories on Tab and the fzf picker on `z foo <Tab>`.
  z() { __zoxide_z "$@"; }
  alias zi='__zoxide_zi'
  compdef __zoxide_z_complete z
fi

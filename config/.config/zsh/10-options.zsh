# 10-options.zsh — shell options
#
# Loaded before history.zsh because SHARE_HISTORY and friends interact.

# EXTENDED_GLOB is needed by the cache-age glob in 30-completion.zsh.
setopt EXTENDED_GLOB

# ── Line editing ───────────────────────────────────────────
setopt AUTO_PARAM_KEYS    # complete after $ in an assignment
setopt AUTO_PARAM_SLASH   # complete after a / inside an assignment
setopt COMPLETE_IN_WORD   # complete mid-word, not just at the end
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP
setopt NO_FLOW_CONTROL    # Ctrl-S / Ctrl-Q reach the terminal

# ── Navigation ─────────────────────────────────────────────
setopt AUTO_CD            # type a directory name to cd into it
setopt PUSHD_IGNORE_DUPS  # "cd -" with duplicates removed
setopt PUSHD_SILENT       # don't list the stack after each pushd

# ── Globbing ───────────────────────────────────────────────
setopt NO_CASE_GLOB       # case-sensitive globs unless asked
setopt NUMERIC_GLOB_SORT  # file2 before file10

# Don't let a failed glob error out in interactive use.
setopt NULL_GLOB
setopt BANG_HIST

# PROMPT_SUBST is deliberately NOT set: the prompt is owned by `pure`
# (50-prompt.zsh), which turns it off itself. Leaving it on here would
# only invite %-escapes in a prompt that does not want them.

# ── Keymap ─────────────────────────────────────────────────
# Emacs mode, stated explicitly instead of left to the default.
#
# `bindkey -e` also resets the main map to the stock emacs bindings, so it
# has to run before anything else binds a key: atuin (20-history.zsh) and
# fzf (40-plugins.zsh) write into whichever map is active, and a reset
# after them would throw their bindings away again.
bindkey -e

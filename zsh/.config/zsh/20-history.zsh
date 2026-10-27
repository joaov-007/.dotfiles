# 20-history.zsh — command history
#
# zsh-autosuggestions reads HISTFILE, so this must be set before the
# plugin loads (it does, via the 35- prefix).

# Keep the history file under XDG data, not scattered in $HOME.
HISTFILE="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/history"
HISTSIZE=100000           # entries kept in memory
SAVEHIST=100000          # entries written to file

mkdir -p "${HISTFILE:h}" 2>/dev/null

setopt SHARE_HISTORY          # shared live across terminals, appended as you type
setopt HIST_REDUCE_BLANKS     # strip redundant spaces
setopt HIST_IGNORE_SPACE      # a leading space keeps a command out of history
setopt HIST_SAVE_NO_DUPS      # don't write duplicates to the file
setopt HIST_FIND_NO_DUPS      # don't return duplicates when searching
setopt HIST_EXPIRE_DUPS_FIRST # trim duplicates before unique entries
setopt HIST_IGNORE_ALL_DUPS   # keep only the newest copy of a command
setopt HIST_VERIFY            # show the expansion, don't run it

# ── Atuin ──────────────────────────────────────────────────
# Syncs shell history across machines with a SQLite backend and replaces
# Ctrl-R with a fuzzy-searchable TUI.
#
# Both switches matter:
#   --disable-up-arrow  keeps ↑/↓ for zsh's own prefix search (60-keys.zsh)
#   --disable-ai        stops atuin from hijacking the ? key, which it
#                       otherwise binds to its AI widget
if (( $+commands[atuin] )); then
  cache_init "$commands[atuin]" atuin.zsh \
    atuin init zsh --disable-up-arrow --disable-ai
fi

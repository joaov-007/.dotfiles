# 35-zinit.zsh — plugin manager
#
# zinit manages zsh plugins and nothing else. Every program it could
# install (fzf, zoxide, atuin, bat, eza, delta) is a pacman package —
# zinit is never used as a package manager.
#
# zinit itself lives in $XDG_DATA_HOME so it stays inside $HOME and
# survives a system upgrade.

ZINIT_HOME="${XDG_DATA_HOME:-$HOME/.local/share}/zinit/zinit.git"

if [[ ! -d $ZINIT_HOME ]]; then
  mkdir -p "${ZINIT_HOME:h}"
  git clone --depth 1 https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
fi

source "${ZINIT_HOME}/zinit.zsh"

# zinit's own completion. The compinit in 30-completion.zsh already ran,
# so the _comps table exists and only needs the entry.
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# ── Plugins ────────────────────────────────────────────────
#
# Order matters:
#
#   1. fast-syntax-highlighting  wraps ZLE widgets, so it goes first
#   2. zsh-autosuggestions       needs the ZLE hooks set up above it
#   3. fzf-tab                   takes over the Tab key, and everything
#                                else that binds a key is bound after it
#
# The prompt is loaded separately, in 50-prompt.zsh, because pure owns
# PROMPT and must not be followed by anything that touches it.
#
# `lucid` silences the loading report; `depth"1"` keeps the clones
# shallow, which is all that is needed to run a plugin.

zinit ice depth"1" lucid
zinit light zdharma-continuum/fast-syntax-highlighting

zinit ice depth"1" lucid
zinit light zsh-users/zsh-autosuggestions

zinit ice depth"1" lucid
zinit light Aloxaf/fzf-tab

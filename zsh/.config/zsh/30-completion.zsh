# 30-completion.zsh — the completion system
#
# compinit is the slowest part of any zsh startup, so the dump is only
# rebuilt once a day and otherwise loaded straight from cache.

autoload -Uz compinit

# (#qN.mh+24) matches the file only if it is older than 24 hours.
# Needs EXTENDED_GLOB, set in 10-options.zsh.
if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit -i
else
  compinit -C -i          # -C skips the security check: cache is ours
fi

zmodload -i zsh/complist   # enables menu selection for the completion list

# ── Matching strategy ──────────────────────────────────────
#   m:{a-zA-Z}={A-Za-z}  type "GIT" to match "git"
#   r:|…  / l:|=…         treat _ . - and = as word separators
#
# Note: 'fuzzy' is intentionally NOT in this list. fzf-tab provides
# fuzzy matching through its fzf interface, and having 'fuzzy' here
# conflicts with fzf-tab's compadd hook, causing:
#   compadd:11: unknown match specification character `f'
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'

# No completion menu. fzf-tab draws its own menu, and it needs the
# unambiguous prefix, which a zsh menu would have already consumed.
zstyle ':completion:*' menu no

zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' special-dirs true      # offer .. ../.. in the menu
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompcache"
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:warnings'     format '%F{red}no completions%f'

# ── Command-specific tweaks ─────────────────────────────────
zstyle ':completion:*:kill:*'    use-color on
zstyle ':completion:*:kill:*'    list-separator ' -- '
zstyle ':completion:*:cd:*'      group-name ''         # hide the ../.. noise
zstyle ':completion:*:man:*'     group-name ''
zstyle ':completion:*:git-checkout:*' group-name ''
zstyle ':completion:*:git-checkout:*' sort false      # keep the branch order
zstyle ':completion:*:sudo:*'    command \
  'sudo -u root -E /usr/bin/env _comp_cd $args'

mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh" 2>/dev/null

# mise completions (needs compinit, so loaded here)
if (( $+commands[mise] )); then
  cache_init "$commands[mise]" mise-completion.zsh mise completion zsh
fi

# cg completions — scripts/chatgpt/cg.py in this repo.
#
# The script writes its own _cg from its argparse parser, so the words
# cannot drift from the commands. That file is cached in ~/.cache/zsh/init
# and regenerated on the next shell after cg.py changes: cache_init
# compares the copy against the binary, and the symlink resolves to the
# script itself. Sourcing the file only defines _cg — compdef binds it.
if (( $+commands[cg] )); then
  cache_init "$commands[cg]" cg.zsh "$commands[cg]" completions zsh
  (( $+functions[_cg] )) && compdef _cg cg
fi

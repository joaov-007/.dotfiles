# 70-aliases.zsh — aliases and small functions
#
# These are conveniences, not dependencies. Comment out freely.

# ── Navigation ─────────────────────────────────────────────
# AUTO_CD covers plain directory names, but not ../.. chains.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# ── Listing ────────────────────────────────────────────────
# eza adds icons and a tree view; ls is the fallback when it is absent.
if command -v eza &>/dev/null; then
  alias l='eza -lh --icons=auto'
  alias ls='eza -1 --icons=auto'
  alias ll='eza -lha --icons=auto --sort=name --group-directories-first'
  alias ld='eza -lhD --icons=auto'
  alias la='eza -la --icons=auto --almost-all'
  alias lt='eza --icons=auto --tree'
  alias ldot='eza -lad --icons=auto .*'
  alias lsize='eza -lhS --icons=auto'
else
  alias l='ls -lh'
  alias ll='ls -lha'
  alias ld='ls -lh --directory'
  alias la='ls -la'
  alias lt='ls -R'
  alias ldot='ls -lad .*'
  alias lsize='ls -lhS'
fi

# ── Common tools ───────────────────────────────────────────
# --color=auto turns the colour off when the output is piped, so these
# are safe in a pipeline.
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias df='df -h'
alias du='du -h'
alias free='free -h'
alias lsblk='lsblk -f'

# No `egrep` alias: GNU grep prints a deprecation warning on every call.
# `grep -E` is the same thing without the noise.
# No `mkdir -p` alias either: it makes `mkdir` succeed when the
# directory is already there, which hides the mistake it was meant to
# report. The `mkcd` function below does the same thing on purpose.

# ── Shortcuts ──────────────────────────────────────────────
alias g='git'
alias h='history'
alias c='clear'
alias j='jobs'
alias v='nvim'
alias rr='trash'
alias please='sudo'    # if you mistype sudo

# ── Git ────────────────────────────────────────────────────
alias gst='git status'
alias ggp='git push'

# ── Functions ──────────────────────────────────────────────

# mkcd: make a directory and enter it.
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# edit: create parent dirs if needed, then open in $EDITOR (fallback nvim).
edit() {
  local file=$1
  [[ -z $file ]] && { print -u2 "edit: usage: edit <file>"; return 1; }
  mkdir -p -- "${file:h}"
  local editor=${EDITOR:-nvim}
  command -v "$editor" >/dev/null || { print -u2 "edit: editor '$editor' not found"; return 1; }
  "$editor" "$file"
}

# zf: zoxide jump with a fuzzy picker, the full "where did I go" flow.
zf() { zoxide query -i -- "$@"; }

# grep the shell history.
fh() { fc -l -r -0 1 2>/dev/null | grep -i -- "$1"; }

# Extract common archive formats into the current directory.
extract() {
  local f=$1
  case $f in
    *.tar.bz2|*.tbz2)  tar xjf  "$f" ;;
    *.tar.gz|*.tgz)    tar xzf  "$f" ;;
    *.tar.xz|*.txz)    tar xJf  "$f" ;;
    *.tar.zst)         tar --zstd -xf "$f" ;;
    *.tar)             tar xf   "$f" ;;
    *.bz2)             bunzip2  "$f" ;;
    *.gz)              gunzip   "$f" ;;
    *.xz)              unxz     "$f" ;;
    *.zst)             unzstd   "$f" ;;
    *.zip)             unzip    "$f" ;;
    *.rar)             unrar x  "$f" ;;
    *.7z)              7z x     "$f" ;;
    *)                 print -u2 "extract: unknown format: $f" && return 1 ;;
  esac
}

# Compress paths into an archive; the format comes from the extension.
#   pack release.tar.gz dist/ docs/
pack() {
  (( $# < 2 )) && { print -u2 "pack: usage: pack <archive> <path>..."; return 1; }
  local archive=$1; shift
  case $archive in
    *.tar.bz2) tar cjf  "$archive" "$@" ;;
    *.tar.gz)  tar czf  "$archive" "$@" ;;
    *.tar.xz)  tar cJf  "$archive" "$@" ;;
    *.tar.zst) tar --zstd -cf "$archive" "$@" ;;
    *.tar)     tar cf   "$archive" "$@" ;;
    *.zip)     zip -r  "$archive" "$@" ;;
    *) print -u2 "pack: unknown format: $archive"; return 1 ;;
  esac
}

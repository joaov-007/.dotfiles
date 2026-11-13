# shellcheck shell=sh
# ~/.config/shell/aliases.sh — aliases and small helpers, POSIX sh.
#
# Sourced by interactive bash and zsh only. Assumes env.sh ran first: it
# relies on DT_OS and EDITOR.
#
# Nothing here is a dependency. Every alias that needs eza, trash, sudo or
# zoxide is only defined when the binary is there, so the same file is
# usable on a fresh macOS or Git Bash install.

# ── Navigation ─────────────────────────────────────────────
# AUTO_CD in zsh covers plain directory names, not ../.. chains.
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'

# ── Listing ────────────────────────────────────────────────
# eza first. Without it, GNU ls and BSD ls disagree on the colour flag:
# --color=auto is GNU, -G is BSD/macOS.
if command -v eza >/dev/null 2>&1; then
    alias l='eza -lh --icons=auto'
    alias ls='eza -1 --icons=auto'
    alias ll='eza -lha --icons=auto --sort=name --group-directories-first'
    alias ld='eza -lhD --icons=auto'
    alias la='eza -la --icons=auto --almost-all'
    alias lt='eza --icons=auto --tree'
    alias ldot='eza -lad --icons=auto .*'
    alias lsize='eza -lhS --icons=auto'
elif [ "$DT_OS" = macos ] || [ "$DT_OS" = unix ]; then
    alias ls='ls -G'
    alias l='ls -lh'
    alias ll='ls -lha'
    alias ld='ls -ldh'
    alias la='ls -la'
    alias lt='ls -R'
    alias ldot='ls -lad .*'
    alias lsize='ls -lhS'
else
    alias ls='ls --color=auto'
    alias l='ls -lh'
    alias ll='ls -lha'
    alias ld='ls -ldh'
    alias la='ls -la'
    alias lt='ls -R'
    alias ldot='ls -lad .*'
    alias lsize='ls -lhS'
fi

# ── Common tools ───────────────────────────────────────────
# --color=auto turns colour off in a pipeline, so these are pipe-safe.
# grep takes --color on GNU and BSD; diff does not, hence the gate.
alias grep='grep --color=auto'
alias df='df -h'
alias du='du -h'

if [ "$DT_OS" = linux ] || [ "$DT_OS" = windows ]; then
    alias diff='diff --color=auto'
fi

# procps / util-linux only. Git Bash and macOS do not ship them.
if [ "$DT_OS" = linux ]; then
    alias free='free -h'
    alias lsblk='lsblk -f'
fi

# No egrep alias: GNU grep warns on every call. No mkdir -p alias either,
# it hides the mistake mkdir was meant to report.
if command -v trash >/dev/null 2>&1; then
    alias rr='trash'
fi
if command -v sudo >/dev/null 2>&1; then
    alias please='sudo'
fi

# ── Shortcuts ──────────────────────────────────────────────
alias g='git'
alias h='fc -l -n'
alias c='clear'
alias j='jobs'
alias v='nvim'

# ── Git ────────────────────────────────────────────────────
alias gst='git status'
alias ggp='git push'

# ── Functions ──────────────────────────────────────────────

# mkcd: make a directory and enter it.
mkcd() {
    [ $# -eq 1 ] || {
        printf 'mkcd: usage: mkcd <dir>\n' >&2
        return 1
    }
    mkdir -p -- "$1" && cd "$1" || return 1
}

# edit: create parent dirs if needed, then open in $EDITOR.
edit() {
    [ $# -eq 1 ] || {
        printf 'edit: usage: edit <file>\n' >&2
        return 1
    }
    mkdir -p -- "$(dirname -- "$1")" 2>/dev/null
    ${EDITOR:-vi} "$1"
}

# zf: zoxide jump with a fuzzy picker.
zf() {
    command -v zoxide >/dev/null 2>&1 || {
        printf 'zf: zoxide not found\n' >&2
        return 1
    }
    zoxide query -i -- "$@"
}

# fh: grep the shell history. fc is the POSIX way in; bash and zsh both
# keep it, dash does not have a history at all.
fh() {
    [ $# -ge 1 ] || {
        printf 'fh: usage: fh <pattern>\n' >&2
        return 1
    }
    fc -l -n -r 2>/dev/null | grep -i -- "$1"
}

# extract: unpack any of the usual formats into the current directory.
extract() {
    [ $# -eq 1 ] || {
        printf 'extract: usage: extract <archive>\n' >&2
        return 1
    }
    [ -f "$1" ] || {
        printf 'extract: not a file: %s\n' "$1" >&2
        return 1
    }
    case $1 in
    *.tar.bz2 | *.tbz2) tar xjf "$1" ;;
    *.tar.gz | *.tgz) tar xzf "$1" ;;
    *.tar.xz | *.txz) tar xJf "$1" ;;
    *.tar.zst) zstd -dc "$1" | tar xf - ;;
    *.tar) tar xf "$1" ;;
    *.bz2) bunzip2 "$1" ;;
    *.gz) gunzip "$1" ;;
    *.xz) unxz "$1" ;;
    *.zst) unzstd "$1" ;;
    *.zip) unzip "$1" ;;
    *.rar) unrar x "$1" ;;
    *.7z) 7z x "$1" ;;
    *)
        printf 'extract: unknown format: %s\n' "$1" >&2
        return 1
        ;;
    esac
}

# pack: archive paths, format taken from the extension.
#   pack release.tar.gz dist/ docs/
pack() {
    [ $# -ge 2 ] || {
        printf 'pack: usage: pack <archive> <path>...\n' >&2
        return 1
    }
    _dt_archive=$1
    shift
    case $_dt_archive in
    *.tar.bz2) tar cjf "$_dt_archive" "$@" ;;
    *.tar.gz) tar czf "$_dt_archive" "$@" ;;
    *.tar.xz) tar cJf "$_dt_archive" "$@" ;;
    *.tar.zst) tar cf - "$@" | zstd -q -o "$_dt_archive" ;;
    *.tar) tar cf "$_dt_archive" "$@" ;;
    *.zip) zip -r "$_dt_archive" "$@" ;;
    *)
        printf 'pack: unknown format: %s\n' "$_dt_archive" >&2
        unset _dt_archive
        return 1
        ;;
    esac
    unset _dt_archive
}

# ── Prompt ─────────────────────────────────────────────────
# zsh owns its prompt (pure, 50-prompt.zsh). bash gets this one so a fresh
# macOS or Git Bash shell is not stuck with the default.
if [ -n "${BASH_VERSION:-}" ] && [ -n "${PS1:-}" ]; then
    PS1='[\u@\h \W]\$ '
fi

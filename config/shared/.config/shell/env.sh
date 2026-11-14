# shellcheck shell=sh
# SC2088: the tilde is expanded by _dt_resolve on purpose; these are
# arguments, not paths the shell should expand.
# shellcheck disable=SC2088
# ~/.config/shell/env.sh — environment shared by sh, bash and zsh.
#
# Works on Linux, macOS and Windows (Git Bash / MSYS2 / WSL). Sourced from:
#
#   ~/.zshenv    every zsh, interactive or not
#   ~/.bashrc    interactive bash
#
# Non-interactive shells read this too, so: variables and PATH only. Nothing
# here may print, alias or touch the prompt.

# ── Platform ───────────────────────────────────────────────
# One knob, DT_OS, instead of a uname test in every file below.
_dt_os=$(uname -s 2>/dev/null) || _dt_os=
# shellcheck disable=SC3028  # OSTYPE is the Git Bash/MSYS fallback
case $_dt_os in
Linux*) DT_OS=linux ;;
Darwin*) DT_OS=macos ;;
MINGW* | MSYS* | CYGWIN*) DT_OS=windows ;;
*) case ${MSYSTEM:-${OSTYPE:-}} in
    MINGW* | MSYS* | UCRT* | CLANG* | msys*) DT_OS=windows ;;
    darwin*) DT_OS=macos ;;
    *) DT_OS=unix ;;
    esac ;;
esac
export DT_OS

# ── XDG ────────────────────────────────────────────────────
# A launcher or .desktop file can export XDG_CONFIG_HOME as the literal
# string "$HOME/.config". Nothing expands it, so the value arrives relative
# and every app resolves it against its own cwd, mkdir -p'ing state there.
# Anything not starting with / is dropped and the default wins.
for _dt_name in XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME; do
    eval "_dt_value=\${$_dt_name:-}"
    # shellcheck disable=SC2154  # assigned by the eval above
    case $_dt_value in
    '' | /*) ;;
    *) unset "$_dt_name" ;;
    esac
done
unset _dt_name _dt_value

: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_DATA_HOME:=$HOME/.local/share}"
: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME

# ── PATH ───────────────────────────────────────────────────
# path_add / path_prepend take "~/dir" or an absolute path and do nothing
# when the directory is missing, so a bare machine stays quiet.
_dt_resolve() {
    case $1 in
    '~') printf '%s\n' "$HOME" ;;
    '~/'*) printf '%s\n' "$HOME/${1#\~/}" ;;
    /*) printf '%s\n' "$1" ;;
    *) printf '%s\n' "$PWD/$1" ;;
    esac
}

path_add() {
    _dt_dir=$(_dt_resolve "$1")
    [ -d "$_dt_dir" ] || return 0
    case ":$PATH:" in
    *":$_dt_dir:"*) ;;
    *) PATH=${PATH:+$PATH:}$_dt_dir ;;
    esac
}

path_prepend() {
    _dt_dir=$(_dt_resolve "$1")
    [ -d "$_dt_dir" ] || return 0
    case ":$PATH:" in
    *":$_dt_dir:"*) ;;
    *) PATH=$_dt_dir${PATH:+:$PATH} ;;
    esac
}

path_add '~/.local/bin'
path_add '~/bin'
path_add '~/.cargo/bin'

# Homebrew. Prepended, not appended: brew's coreutils and sed should win
# over the BSD ones in /usr/bin. Apple silicon first, Intel second.
if [ "$DT_OS" = macos ]; then
    path_prepend /usr/local/bin
    path_prepend /opt/homebrew/bin
fi

# SSH agent socket. systemd user sockets on Linux only; macOS gets
# SSH_AUTH_SOCK from launchd and Windows from its own agent.
#
# Order of preference, first socket that actually exists wins:
#
#   gcr/ssh            gcr-ssh-agent, the GNOME Keyring SSH helper. The ssh
#                      component was moved out of gnome-keyring-daemon into
#                      gcr-4 in gnome-keyring 1:46, so this is the keyring
#                      agent on a current Arch box.
#   keyring/ssh        gnome-keyring-daemon's own ssh component, for older
#                      stacks or anyone who still starts it by hand.
#   ssh-agent.socket   plain OpenSSH agent, the fallback.
#
# An inherited SSH_AUTH_SOCK (herdr, ssh-agent -a, a forwarded socket) is
# kept as long as it is a live socket; a stale path is replaced instead of
# poisoning every ssh call with "connection refused".
if [ "$DT_OS" = linux ]; then
    _dt_agent=${SSH_AUTH_SOCK:-}
    if [ -z "$_dt_agent" ] || [ ! -S "$_dt_agent" ]; then
        # shellcheck disable=SC3028  # UID is a bash/zsh convenience, id(1) is the fallback
        _dt_run=${XDG_RUNTIME_DIR:-/run/user/${UID:-$(id -u)}}
        for _dt_sock in "$_dt_run/gcr/ssh" "$_dt_run/keyring/ssh" "$_dt_run/ssh-agent.socket"; do
            if [ -S "$_dt_sock" ]; then
                SSH_AUTH_SOCK=$_dt_sock
                export SSH_AUTH_SOCK
                break
            fi
        done
        unset _dt_sock _dt_run
    fi
    unset _dt_agent
fi

# ── Editors and pagers ─────────────────────────────────────
# First one that exists wins; vi is the POSIX floor.
if command -v nvim >/dev/null 2>&1; then
    EDITOR=nvim
elif command -v vim >/dev/null 2>&1; then
    EDITOR=vim
else
    EDITOR='vi'
fi
VISUAL=$EDITOR
DIFFPROG="$EDITOR -d"
export EDITOR VISUAL DIFFPROG

if command -v less >/dev/null 2>&1; then
    PAGER='less -R'
else
    PAGER='cat'
fi
export PAGER

# bat keeps the bold and the underline that `man | less` throws away.
# col -bx unfolds the backspaces first, otherwise bat shows raw escapes.
# Both are GNU and BSD col, so the same line works on macOS.
if command -v bat >/dev/null 2>&1 && command -v col >/dev/null 2>&1; then
    # A command line is exactly what MANPAGER is for; shellcheck sees the
    # quotes as a mistake.
    # shellcheck disable=SC2089
    MANPAGER="sh -c 'col -bx | bat --language=man --style=plain --paging=always'"
    # shellcheck disable=SC2090
    export MANPAGER
fi

# ── Tools ──────────────────────────────────────────────────
export GITHUB_USERNAME="joaov-007"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

# CARGO_TARGET_DIR points at a bin directory on this machine on purpose.
# Change it before using this repo somewhere else: build artifacts do not
# belong in a directory full of executables.
export CARGO_TARGET_DIR="$HOME/.local/bin"

GOBIN="$HOME/go/bin"
export GOBIN
path_add "$GOBIN"

if command -v pnpm >/dev/null 2>&1; then
    PNPM_HOME="$HOME/.local/share/pnpm"
    export PNPM_HOME
    path_add "$PNPM_HOME"
fi

# gpg-agent needs the terminal it is talking to. Only ask when there is one.
if [ -z "${GPG_TTY:-}" ] && [ -t 0 ]; then
    GPG_TTY=$(tty 2>/dev/null) || GPG_TTY=
    [ -n "$GPG_TTY" ] && export GPG_TTY
fi

# ── Linux-only desktop plumbing ────────────────────────────
# Qt theme picker, X11 client cookie and the rootless Podman socket. All
# three are meaningless on macOS and in Git Bash, so they are gated here
# instead of leaking a broken path into every other shell.
if [ "$DT_OS" = linux ]; then
    export QT_QPA_PLATFORMTHEME=qt6ct
    export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

    # Docker-API clients (devcontainer, compose, testcontainers) talk to the
    # rootless Podman socket. The session-wide copy is in
    # ~/.config/environment.d/podman.conf.
    if command -v podman >/dev/null 2>&1 && [ -n "${XDG_RUNTIME_DIR:-}" ]; then
        export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
    fi
fi

unset _dt_os _dt_dir

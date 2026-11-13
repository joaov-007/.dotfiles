#!/bin/sh
# Bootstrap git configuration when Home Manager is not available yet.
set -eu

SCOPE=--global
DRY_RUN=0
VERBOSE=0

if [ -t 1 ]; then
    RED=$(printf '\033[0;31m')
    GREEN=$(printf '\033[0;32m')
    YELLOW=$(printf '\033[0;33m')
    BLUE=$(printf '\033[0;34m')
    RESET=$(printf '\033[0m')
else
    RED=
    GREEN=
    YELLOW=
    BLUE=
    RESET=
fi

show_help() {
    cat <<EOF
Usage: $0 [OPTIONS]

Options:
--global          Use global git config (default)
--local           Use repository config
--system          Use system config

-n, --dry-run     Show changes without applying them
-v, --verbose     Show extra information
-h, --help        Show this help

Examples:
$0
$0 --local
$0 --dry-run --verbose
EOF
}

log() {
    printf '%b\n' "$*"
}

debug() {
    [ "$VERBOSE" -eq 1 ] || return 0
    printf '%b\n' "${BLUE}[debug]${RESET} $*"
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || {
        log "${RED}Error:${RESET} required command not found: $1"
        exit 1
    }
}

while [ "$#" -gt 0 ]; do
    case $1 in
    --global) SCOPE=--global ;;
    --local) SCOPE=--local ;;
    --system) SCOPE=--system ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -v | --verbose) VERBOSE=1 ;;
    -h | --help)
        show_help
        exit 0
        ;;
    *)
        log "${RED}Unknown option:${RESET} $1"
        exit 1
        ;;
    esac
    shift
done

require_command git

debug "scope     = $SCOPE"
debug "dry-run   = $DRY_RUN"
debug "verbose   = $VERBOSE"

set_kv() {
    kv_key=$1
    kv_value=$2

    [ -n "$kv_key" ] || return 0

    debug "processing: $kv_key=$kv_value"

    if [ "$DRY_RUN" -eq 1 ]; then
        log "${BLUE}[dry-run]${RESET} $kv_key = ${GREEN}$kv_value${RESET}"
        return 0
    fi

    case $kv_value in
    unset | null)
        if git config "$SCOPE" --get "$kv_key" >/dev/null 2>&1; then
            git config "$SCOPE" --unset "$kv_key"
            log "${YELLOW}Unset:${RESET} $kv_key"
        else
            debug "$kv_key already absent"
        fi
        return 0
        ;;
    esac

    git config "$SCOPE" "$kv_key" "$kv_value"
    log "${GREEN}Set:${RESET} $kv_key = $kv_value"
}

apply_collection() {
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        key=${line%%=*}
        value=${line#*=}
        [ "$key" = "$line" ] && continue
        set_kv "$key" "$value"
    done
}

apply_collection <<'EOF'
branch.autosetuprebase=always
fetch.prune=true
pull.default=current
pull.rebase=true
push.autoSetupRemote=true
push.default=current
rebase.autoSquash=true
rebase.autoStash=true
rebase.stat=true
rerere.autoUpdate=true
rerere.enabled=true
diff.submodule=log
EOF

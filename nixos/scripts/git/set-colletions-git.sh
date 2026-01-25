#!/usr/bin/env bash
set -euo pipefail

# Default scope and flags
CONFIG_SCOPE="--local"
DRY_RUN=false

# Detect if output is a terminal
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    RESET='\033[0m'
else
    # Disable colors for non-interactive output
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    RESET=''
fi

# Parse options
while (( $# )); do
    case "$1" in
        --global|--local|--system)
            CONFIG_SCOPE="$1"
            shift
            ;;
        --dry-run|-n)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            cat <<EOF
Usage: $0 [--global|--local|--system] [--dry-run]

--dry-run, -n   Show what would be applied (no git config calls)
EOF
            exit
            ;;
        *)
            echo -e "${RED}Unknown option:${RESET} $1"
            exit 1
            ;;
    esac
done

# List of git config key/value pairs
git_options=(
    branch.autosetuprebase always
    color.ui auto
    core.preloadindex true
    fetch.prune true
    gc.auto 10000
    gc.autoPackLimit 50
    pull.default current
    pull.rebase true
    push.autoSetupRemote true
    push.default current
    rebase.autoSquash true
    rebase.autoStash true
    rebase.stat true
    rerere.autoUpdate true
    rerere.enabled true
)

set_kv() {
    local key="$1"
    local value="$2"

    if [[ "$DRY_RUN" == true ]]; then
        # Dry-run output
        echo -e "${BLUE}[dry-run]${RESET} would set ${YELLOW}${key}${RESET} = ${GREEN}${value}${RESET}"
        return
    fi

    if [[ "$value" =~ ^(unset|null)$ ]]; then
        if git config $CONFIG_SCOPE --unset "$key"; then
            echo -e "${YELLOW}Unset:${RESET} ${key}"
        else
            echo -e "${RED}Failed to unset:${RESET} ${key}"
        fi
    else
        if git config $CONFIG_SCOPE "$key" "$value"; then
            echo -e "${GREEN}Set:${RESET} ${key} = ${value}"
        else
            echo -e "${RED}Error setting:${RESET} ${key}"
        fi
    fi
}

apply_collection() {
    local -n arr=$1
    (( ${#arr[@]} % 2 == 0 )) || {
        echo -e "${RED}Error:${RESET} key/value pairs required"
        return 1
    }

    while (( ${#arr[@]} )); do
        set_kv "${arr[0]}" "${arr[1]}"
        arr=("${arr[@]:2}")
    done
}

apply_collection git_options

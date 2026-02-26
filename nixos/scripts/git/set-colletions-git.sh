#!/usr/bin/env bash
##
# this script help bootsrap the system
# when the git home manager is not
# working
##

set -euo pipefail

# Default scope and flags
CONFIG_SCOPE="--global"
DRY_RUN=false

# List of git config key/value pairs
git_options=(
    branch.autosetuprebase always
    fetch.prune true
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

show_help () {
cat <<EOF
   Usage: $0 [--global|--local|--system] [--dry-run]

   --dry-run, -n   Show what would be applied (no git config calls)
EOF
}

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
            show_help
            exit
            ;;
        *)
            echo -e "${RED}Unknown option:${RESET} $1"
            exit 1
            ;;
    esac
done

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

setCollection() {
    # Must be key/value pairs
    (( $# % 2 == 0 )) || {
        echo "Error: key/value pairs required" >&2
        return 1
    }

    while [ "$#" -gt 0 ]; do
        key=$1
        value=$2

        # Validate key
        if [[ -z "$key" ]]; then
            echo "Error: empty git config key" >&2
            return 1
        fi

        case "$value" in
            ""|unset|null)
                git config --unset "$key" || {
                    echo "Warning: failed to unset $key" >&2
                }
                ;;
            *)
                git config "$key" "$value" || {
                    echo "Error: failed to set $key=$value" >&2
                    return 1
                }
                ;;
        esac

        shift 2
    done
}


setCollection "${git_options[@]}"

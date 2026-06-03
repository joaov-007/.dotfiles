#!/usr/bin/env bash

##

# Bootstrap git configuration when Home Manager

# is not available yet.

##

set -Eeuo pipefail

CONFIG_SCOPE="--global"
DRY_RUN=false
VERBOSE=false

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

if [[ -t 1 ]]; then
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
RESET=$'\033[0m'
else
RED=""
GREEN=""
YELLOW=""
BLUE=""
RESET=""
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
[[ "$VERBOSE" == true ]] || return 0
printf '%b\n' "${BLUE}[debug]${RESET} $*"
}

require_command() {
command -v "$1" >/dev/null 2>&1 || {
log "${RED}Error:${RESET} required command not found: $1"
exit 1
}
}

while (($#)); do
case "$1" in
--global|--local|--system)
CONFIG_SCOPE="$1"
;;
-n|--dry-run)
DRY_RUN=true
;;
-v|--verbose)
VERBOSE=true
;;
-h|--help)
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

debug "scope     = $CONFIG_SCOPE"
debug "dry-run   = $DRY_RUN"
debug "verbose   = $VERBOSE"

set_kv() {
local key="$1"
local value="$2"


debug "processing: $key=$value"

if [[ "$DRY_RUN" == true ]]; then
    log "${BLUE}[dry-run]${RESET} $key = ${GREEN}$value${RESET}"
    return 0
fi

if [[ "$value" =~ ^(unset|null)$ ]]; then
    if git config $CONFIG_SCOPE --get "$key" >/dev/null 2>&1; then
        git config $CONFIG_SCOPE --unset "$key"
        log "${YELLOW}Unset:${RESET} $key"
    else
        debug "$key already absent"
    fi
    return 0
fi

git config $CONFIG_SCOPE "$key" "$value"
log "${GREEN}Set:${RESET} $key = $value"

}

apply_collection() {
local arr=("$@")

(( ${#arr[@]} % 2 == 0 )) || {
    log "${RED}Error:${RESET} key/value pairs required"
    return 1
}

local i

for ((i=0; i<${#arr[@]}; i+=2)); do
    set_kv "${arr[i]}" "${arr[i+1]}"
done

}

apply_collection "${git_options[@]}"


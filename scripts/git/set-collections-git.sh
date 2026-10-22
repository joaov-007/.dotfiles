#!/usr/bin/env bash

# Bootstrap git configuration when Home Manager is not available yet.

set -Eeuo pipefail

CONFIG_SCOPE_ARGS=(--global)
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
diff.submodule log
)

if [[ -t 1 ]]; then
readonly RED=$'\033[0;31m'
readonly GREEN=$'\033[0;32m'
readonly YELLOW=$'\033[0;33m'
readonly BLUE=$'\033[0;34m'
readonly RESET=$'\033[0m'
else
readonly RED=""
readonly GREEN=""
readonly YELLOW=""
readonly BLUE=""
readonly RESET=""
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

while [[ $# -gt 0 ]]; do
case "$1" in
--global)
CONFIG_SCOPE_ARGS=(--global)
;;
--local)
CONFIG_SCOPE_ARGS=(--local)
;;
--system)
CONFIG_SCOPE_ARGS=(--system)
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

debug "scope     = ${CONFIG_SCOPE_ARGS[*]}"
debug "dry-run   = $DRY_RUN"
debug "verbose   = $VERBOSE"

set_kv() {
local key="$1"
local value="$2"

[[ -n "$key" ]] || return 0

debug "processing: $key=$value"

if [[ "$DRY_RUN" == true ]]; then
    log "${BLUE}[dry-run]${RESET} $key = ${GREEN}$value${RESET}"
    return 0
fi

if [[ "$value" =~ ^(unset|null)$ ]]; then
    if git config "${CONFIG_SCOPE_ARGS[@]}" --get "$key" >/dev/null 2>&1; then
        git config "${CONFIG_SCOPE_ARGS[@]}" --unset "$key"
        log "${YELLOW}Unset:${RESET} $key"
    else
        debug "$key already absent"
    fi
    return 0
fi

git config "${CONFIG_SCOPE_ARGS[@]}" "$key" "$value"
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


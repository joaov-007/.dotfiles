#!/usr/bin/env bash
set -euo pipefail

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

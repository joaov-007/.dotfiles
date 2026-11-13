#!/bin/sh
# Run one compose action across the app stacks in APPS_DIR.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -P -- "$SCRIPT_DIR/../../.." && pwd -P)
APPS_DIR=${APPS_DIR:-$REPO_ROOT/apps/tmp}
APPS=${APPS:-caddy dagu homer}
ACTION=${1:-}

case $ACTION in
up | down | restart | ps | logs | pull) ;;
*)
    printf 'Usage: %s {up|down|restart|ps|logs|pull}\n' "$0" >&2
    exit 1
    ;;
esac

for app in $APPS; do
    if [ ! -d "$APPS_DIR/$app" ]; then
        printf '\n==> %s: skipped, no such directory: %s\n' "$app" "$APPS_DIR/$app" >&2
        continue
    fi

    printf '\n==> %s: %s\n' "$app" "$ACTION"

    (
        cd -P "$APPS_DIR/$app"

        case $ACTION in
        up) podman compose up -d ;;
        down) podman compose down ;;
        restart) podman compose restart ;;
        ps) podman compose ps ;;
        logs) podman compose logs --tail=50 ;;
        pull) podman compose pull ;;
        esac
    )
done

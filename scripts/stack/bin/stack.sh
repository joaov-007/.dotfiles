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

case $APPS_DIR in
/*) ;;
*)
    printf 'Error: APPS_DIR must be an absolute path: %s\n' "$APPS_DIR" >&2
    exit 1
    ;;
esac
[ -d "$APPS_DIR" ] || {
    printf 'Error: APPS_DIR does not exist: %s\n' "$APPS_DIR" >&2
    exit 1
}

for app in $APPS; do
    case $app in
    '' | *[!A-Za-z0-9._-]* | . | ..)
        printf '\n==> %s: skipped, invalid app name\n' "$app" >&2
        continue
        ;;
    esac

    app_dir=$APPS_DIR/$app
    if [ ! -d "$app_dir" ]; then
        printf '\n==> %s: skipped, no such directory: %s\n' "$app" "$app_dir" >&2
        continue
    fi
    case $app_dir in
    "$APPS_DIR"/*) ;;
    *)
        printf '\n==> %s: skipped, refuses path outside APPS_DIR\n' "$app" >&2
        continue
        ;;
    esac

    printf '\n==> %s: %s\n' "$app" "$ACTION"

    (
        cd -P "$app_dir"

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

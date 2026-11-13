#!/bin/sh
# make-app.sh - scaffold or remove app stacks under apps/<host>/<app>.
set -eu

APPS_ROOT=${APPS_ROOT:-$HOME/.dotfiles/apps}

usage() {
    cat <<'EOF'
Usage:
  make-app.sh <host>... <app>              create app stack(s)
  make-app.sh --trash <host>... <app>      move stack(s) to the system trash
  make-app.sh --delete <host>... <app>     permanently remove stack(s)

The last argument is always the app name; every preceding argument is a host.
Create the same app on several hosts at once:

  make-app.sh bacon duck searxng

Options:
  -t, --trash    move the app directory to the trash instead of creating
  -d, --delete   permanently delete the app directory
  -f, --force    do not ask for confirmation on --delete
  -h, --help     show this help

Environment:
  APPS_ROOT      Apps root (default: ~/.dotfiles/apps)
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

valid_name() {
    case $1 in
    '' | [!A-Za-z0-9]* | *[!A-Za-z0-9._-]*) return 1 ;;
    esac
    return 0
}

trash_dir() {
    if command -v gio >/dev/null 2>&1; then
        gio trash -- "$1"
    elif command -v trash-put >/dev/null 2>&1; then
        trash-put -- "$1"
    elif command -v kioclient5 >/dev/null 2>&1; then
        kioclient5 move "$1" trash:/
    elif command -v kioclient >/dev/null 2>&1; then
        kioclient move "$1" trash:/
    else
        die "no trash command found (install glib2, trash-cli, or kde-cli-tools)"
    fi
}

mode=create
force=0
args=
while [ "$#" -gt 0 ]; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -t | --trash) mode=trash ;;
    -d | --delete) mode=delete ;;
    -f | --force) force=1 ;;
    --)
        shift
        while [ "$#" -gt 0 ]; do
            if [ -n "$args" ]; then args="$args
$1"; else args=$1; fi
            shift
        done
        break
        ;;
    -*) die "unknown option: $1 (see --help)" ;;
    *)
        if [ -n "$args" ]; then args="$args
$1"; else args=$1; fi
        ;;
    esac
    shift
done

argc=$(printf '%s\n' "$args" | wc -l | tr -d ' ')
[ "$argc" -ge 2 ] || {
    usage >&2
    exit 1
}

app_name=$(printf '%s\n' "$args" | tail -n 1)
hosts_list=$(printf '%s\n' "$args" | sed '$d' | sort -u)

valid_name "$app_name" || die "invalid application name: $app_name"

while IFS= read -r host; do
    [ -n "$host" ] || continue
    valid_name "$host" || die "invalid host name: $host"
done <<EOF
$hosts_list
EOF

case $mode in
create) printf 'Creating application: %s\n' "$app_name" ;;
trash) printf 'Trashing application: %s\n' "$app_name" ;;
delete) printf 'Deleting application: %s\n' "$app_name" ;;
esac
hosts_display=$(printf '%s\n' "$hosts_list" | tr '\n' ' ')
printf '  hosts: %s\n' "${hosts_display% }"

for host in $hosts_list; do
    app_dir="$APPS_ROOT/$host/$app_name"

    case $mode in
    create)
        printf '\n[%s] creating: %s\n' "$host" "$app_dir"
        mkdir -p "$app_dir"

        for dir in data scripts configs containers containers/systemd; do
            mkdir -p "$app_dir/$dir"
        done

        compose_file="$app_dir/compose.yaml"

        if [ ! -e "$compose_file" ]; then
            : >"$compose_file"
            chmod 644 "$compose_file"
            printf 'Created: %s\n' "$compose_file"
        else
            printf 'Exists: %s\n' "$compose_file"
        fi
        ;;

    trash | delete)
        if [ ! -e "$app_dir" ]; then
            printf '\n[%s] skipped, does not exist: %s\n' "$host" "$app_dir" >&2
            continue
        fi
        [ -d "$app_dir" ] || die "not a directory: $app_dir"
        [ ! -L "$app_dir" ] || die "refusing to touch a symlink: $app_dir"

        if [ "$mode" = trash ]; then
            printf '\n[%s] moving to trash: %s\n' "$host" "$app_dir"
            trash_dir "$app_dir"
            printf 'Trashed: %s\n' "$app_dir"
        else
            if [ "$force" -eq 0 ]; then
                if [ -t 0 ]; then
                    printf 'Permanently delete %s? [y/N] ' "$app_dir"
                    reply=
                    IFS= read -r reply || reply=
                    case $reply in
                    y | Y) ;;
                    *)
                        printf 'Skipped: %s\n' "$app_dir"
                        continue
                        ;;
                    esac
                else
                    die "refusing to delete without --force: $app_dir"
                fi
            fi
            printf '\n[%s] deleting: %s\n' "$host" "$app_dir"
            rm -rf -- "$app_dir"
            printf 'Deleted: %s\n' "$app_dir"
        fi
        ;;
    esac
done

if [ "$mode" = create ]; then
    printf '\nDone: %s\n' "$app_name"
fi

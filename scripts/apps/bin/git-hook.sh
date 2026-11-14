#!/bin/sh
# git-hook.sh - install, inspect and remove the apps pre-push hook.
#
# The hook is a marked block inside .git/hooks/pre-push (or core.hooksPath).
# It appends to whatever is already there and replaces only its own block on
# reinstall, so it never fights another hook manager. Removing it leaves the
# rest of the file untouched.
set -eu

SCRIPT_DIR=$(CDPATH='' cd -P -- "$(dirname -- "$0")" && pwd -P)
REPO_ROOT=$(CDPATH='' cd -P -- "$SCRIPT_DIR/../../.." && pwd -P)

HOOK_NAME="pre-push"
BEGIN_MARK="# >>> sync-apps ${HOOK_NAME} >>>"
END_MARK="# <<< sync-apps ${HOOK_NAME} <<<"

COMMAND=""
DRY_RUN=0
QUIET=0
CLEANUP_FILES=""

cleanup() {
    printf '%s' "$CLEANUP_FILES" |
        while IFS= read -r file; do
            [ -n "$file" ] || continue
            rm -f -- "$file"
        done
}
trap cleanup 0

add_cleanup() {
    CLEANUP_FILES="$CLEANUP_FILES$1
"
}

usage() {
    cat <<'EOF'
Usage: git-hook.sh [OPTIONS] <install|uninstall|status>

Manage the sync-apps pre-push hook for this repository.

Commands:
  install     Add the marked block to .git/hooks/pre-push (idempotent).
  uninstall   Remove only the marked block, keeping other hook content.
  status      Show the hook path, block presence and foreign content.

Options:
  -n, --dry-run   Print what would change; write nothing.
  -q, --quiet     Only print warnings and errors.
  -h, --help      Show this help.

The hook validates apps/ compose files with "sync-apps.sh validate --local"
only when the commits being pushed touch apps/. Skip it once with:
  git push --no-verify
EOF
}

now() { date +%H:%M:%S; }

log() {
    level=$1
    shift
    if [ "$QUIET" -eq 1 ] && [ "$level" != WARN ] && [ "$level" != ERROR ]; then
        return 0
    fi
    printf '%s %-5s %s\n' "$(now)" "$level" "$*" >&2
}

info() { log INFO "$*"; }
warn() { log WARN "$*"; }
err() { log ERROR "$*"; }
die() {
    err "$*"
    exit 1
}

hook_path() {
    dir=$(git -C "$REPO_ROOT" rev-parse --path-format=absolute --git-path hooks 2>/dev/null) ||
        dir=$(git -C "$REPO_ROOT" rev-parse --git-path hooks 2>/dev/null) ||
        dir="$REPO_ROOT/.git/hooks"
    case $dir in
    /*) ;;
    *) dir="$REPO_ROOT/$dir" ;;
    esac
    printf '%s/%s' "${dir%/}" "$HOOK_NAME"
}

hooks_path_override() {
    git -C "$REPO_ROOT" config --get core.hooksPath 2>/dev/null || true
}

hook_block() {
    cat <<'BLOCK'
# >>> sync-apps pre-push >>>
# Managed by scripts/apps/bin/git-hook.sh; edit the generator, not this block.
# Validates apps/ compose files before pushing commits that touch apps/.
if command -v git >/dev/null 2>&1; then
  __sync_apps_root=$(git rev-parse --show-toplevel 2>/dev/null) || __sync_apps_root=
  __sync_apps_runner=${__sync_apps_root}/scripts/apps/bin/sync-apps.sh

  if [ -n "$__sync_apps_root" ] && [ -d "$__sync_apps_root/apps" ] && [ -x "$__sync_apps_runner" ]; then
    __sync_apps_changed=1
    if __sync_apps_upstream=$(git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null); then
      git diff --quiet "$__sync_apps_upstream" HEAD -- apps/ 2>/dev/null && __sync_apps_changed=0
    fi

    if [ "$__sync_apps_changed" -eq 1 ]; then
      if ! command -v podman >/dev/null 2>&1; then
        printf 'pre-push: podman not installed, apps validation skipped\n' >&2
      else
        printf '\npre-push: apps/ changed, validating compose files\n' >&2
        if "$__sync_apps_runner" validate --local --quiet; then
          :
        else
          printf 'pre-push: apps validation failed; push aborted\n' >&2
          printf 'pre-push: fix the compose file, or skip with: git push --no-verify\n' >&2
          exit 1
        fi
      fi
    fi
  fi
fi
# <<< sync-apps pre-push <<<
BLOCK
}

write_block_file() {
    hook_block >"$1"
    sh -n "$1" || die "generated hook block has a syntax error"
}

merge_block() {
    target=$1
    block=$2
    tmp=$(mktemp "${target}.XXXXXX")
    add_cleanup "$tmp"

    if grep -qxF "$BEGIN_MARK" "$target" 2>/dev/null; then
        awk -v blockfile="$block" -v begin="$BEGIN_MARK" -v end="$END_MARK" '
      $0 == begin {
        while ((getline line < blockfile) > 0) print line
        close(blockfile)
        inside = 1
        next
      }
      inside && $0 == end { inside = 0; next }
      !inside { print }
    ' "$target" >"$tmp"
    else
        cat "$target" >"$tmp"
        if [ -s "$tmp" ] && [ -n "$(tail -c 1 "$tmp")" ]; then
            printf '\n' >>"$tmp"
        fi
        printf '\n' >>"$tmp"
        cat "$block" >>"$tmp"
    fi

    chmod 755 "$tmp"
    mv -- "$tmp" "$target"
}

cmd_install() {
    target=$(hook_path)
    override=$(hooks_path_override)

    if [ -n "$override" ]; then
        info "core.hooksPath is set to '${override}'; installing where git looks (${target})"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        if [ -e "$target" ] && grep -qxF "$BEGIN_MARK" "$target"; then
            info "dry-run: would refresh the sync-apps block in ${target}"
        elif [ -e "$target" ]; then
            info "dry-run: would append the sync-apps block to ${target}"
        else
            info "dry-run: would create ${target} with the sync-apps block"
        fi
        return 0
    fi

    mkdir -p "$(dirname "$target")"

    block=$(mktemp)
    add_cleanup "$block"
    write_block_file "$block"

    if [ ! -e "$target" ]; then
        {
            printf '#!/bin/sh\n\n'
            cat "$block"
        } >"$target"
        chmod 755 "$target"
        info "created ${target}"
    else
        [ -f "$target" ] || die "hook path is not a regular file: ${target}"
        if grep -qxF "$BEGIN_MARK" "$target"; then
            merge_block "$target" "$block"
            info "refreshed the sync-apps block in ${target}"
        else
            merge_block "$target" "$block"
            info "appended the sync-apps block to ${target} (existing content kept)"
        fi
        [ -x "$target" ] || chmod +x "$target"
    fi
}

cmd_uninstall() {
    target=$(hook_path)

    if [ ! -e "$target" ]; then
        info "nothing to do: ${target} does not exist"
        return 0
    fi
    if ! grep -qxF "$BEGIN_MARK" "$target"; then
        info "nothing to do: no sync-apps block in ${target}"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        info "dry-run: would remove the sync-apps block from ${target}"
        return 0
    fi

    tmp=$(mktemp "${target}.XXXXXX")
    add_cleanup "$tmp"
    awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
    $0 == begin { inside = 1; next }
    inside && $0 == end { inside = 0; next }
    !inside { print }
  ' "$target" >"$tmp"

    if ! grep -qvE '^(#!.*)?[[:space:]]*$' "$tmp"; then
        rm -f -- "$tmp"
        rm -f -- "$target"
        info "removed ${target} (it only held the sync-apps block)"
        return 0
    fi

    chmod 755 "$tmp"
    mv -- "$tmp" "$target"
    info "removed the sync-apps block from ${target}"
}

cmd_status() {
    target=$(hook_path)
    override=$(hooks_path_override)

    printf 'hook:   %s\n' "$target"
    if [ -n "$override" ]; then
        printf 'source: core.hooksPath=%s\n' "$override"
    else
        printf 'source: .git/hooks\n'
    fi

    if [ ! -e "$target" ]; then
        printf 'state:  missing\n'
        return 0
    fi
    if grep -qxF "$BEGIN_MARK" "$target"; then
        printf 'state:  installed\n'
    else
        printf 'state:  not installed\n'
    fi

    if awk -v begin="$BEGIN_MARK" -v end="$END_MARK" '
      $0 == begin { inside = 1; next }
      inside && $0 == end { inside = 0; next }
      !inside && $0 !~ /^#!.*$/ && $0 !~ /^[[:space:]]*$/ { found = 1 }
      END { exit(found ? 0 : 1) }
    ' "$target"; then
        printf 'other:  yes (foreign hook content present)\n'
    else
        printf 'other:  no\n'
    fi
}

while [ "$#" -gt 0 ]; do
    case $1 in
    -h | --help)
        usage
        exit 0
        ;;
    -n | --dry-run) DRY_RUN=1 ;;
    -q | --quiet) QUIET=1 ;;
    --)
        shift
        break
        ;;
    -*) die "unknown option: $1 (try --help)" ;;
    *)
        [ -z "$COMMAND" ] || die "unexpected argument: $1"
        COMMAND=$1
        ;;
    esac
    shift
done

[ -n "$COMMAND" ] || {
    usage >&2
    exit 1
}

git -C "$REPO_ROOT" rev-parse --git-dir >/dev/null 2>&1 ||
    die "not a git repository: ${REPO_ROOT}"

case $COMMAND in
install) cmd_install ;;
uninstall) cmd_uninstall ;;
status) cmd_status ;;
*) die "unknown command: ${COMMAND} (try --help)" ;;
esac

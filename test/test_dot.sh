#!/bin/sh
# test_dot.sh — feature/health tests for bin/dot (POSIX sh)
# Run from repository root: sh test/test_dot.sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
# Support running from repo root or from test/ directory.
if [ -x "$SCRIPT_DIR/../bin/dot" ]; then
    ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd -P)
elif [ -x "$SCRIPT_DIR/bin/dot" ]; then
    ROOT=$SCRIPT_DIR
else
    printf '%s\n' "cannot locate bin/dot relative to $SCRIPT_DIR" >&2
    exit 1
fi
DOT="$ROOT/bin/dot"

pass_count=0
fail_count=0
skip_count=0
tmp_root=

log() { printf '%s\n' "$*"; }
pass() {
    pass_count=$((pass_count + 1))
    log "PASS: $1"
}
fail() {
    fail_count=$((fail_count + 1))
    log "FAIL: $1${2:+ - $2}"
}
skip() {
    skip_count=$((skip_count + 1))
    log "SKIP: $1${2:+ - $2}"
}

cleanup() {
    if [ -n "${tmp_root:-}" ] && [ -d "$tmp_root" ]; then
        rm -rf -- "$tmp_root"
    fi
}
trap cleanup EXIT INT TERM

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        log "missing required command: $1"
        exit 1
    }
}

assert_eq() {
    _want=$1 _got=$2 _msg=$3
    if [ "$_want" = "$_got" ]; then
        pass "$_msg"
    else
        fail "$_msg" "expected [$_want], got [$_got]"
    fi
}

assert_true() {
    _msg=$1
    shift
    if "$@"; then
        pass "$_msg"
    else
        fail "$_msg" "command failed: $*"
    fi
}

assert_false() {
    _msg=$1
    shift
    if "$@"; then
        fail "$_msg" "expected failure but succeeded: $*"
    else
        pass "$_msg"
    fi
}

assert_file() { [ -f "$1" ]; }
assert_dir() { [ -d "$1" ]; }
assert_link() { [ -L "$1" ]; }
assert_exists() { [ -e "$1" ] || [ -L "$1" ]; }
assert_missing() { [ ! -e "$1" ] && [ ! -L "$1" ]; }

assert_contains() {
    _haystack=$1 _needle=$2 _msg=$3
    case $_haystack in
    *"$_needle"*) pass "$_msg" ;;
    *) fail "$_msg" "expected output to contain [$_needle], got [$_haystack]" ;;
    esac
}

readlink_target() {
    if command -v readlink >/dev/null 2>&1; then
        readlink -- "$1"
    else
        LC_ALL=C ls -ld -- "$1" 2>/dev/null | sed 's/.* -> //'
    fi
}

new_case() {
    case_name=$1
    case_dir=$tmp_root/$case_name
    repo=$case_dir/repo
    target=$case_dir/home
    mkdir -p -- "$repo/bin" "$repo/config" "$target"
    cp -- "$DOT" "$repo/bin/dot"
    chmod +x "$repo/bin/dot"
}

write_file() {
    _path=$1
    shift
    mkdir -p -- "$(dirname -- "$_path")"
    # shellcheck disable=SC2059
    printf '%s' "$*" >"$_path"
}

run_dot() {
    _repo=$1 _target=$2
    shift 2
    DOTFILES_TARGET=$_target "$_repo/bin/dot" "$@"
}

# ── preflight ──────────────────────────────────────────────────────────────
need_cmd mkdir
need_cmd cp
need_cmd rm
need_cmd chmod
need_cmd find
need_cmd uname

if [ ! -x "$DOT" ]; then
    log "bin/dot is missing or not executable: $DOT"
    exit 1
fi

tmp_root=${TMPDIR:-/tmp}/dot-test.$$
mkdir -p -- "$tmp_root"

log "== dot test suite =="
log "repo: $ROOT"

# ── feature: help / args ───────────────────────────────────────────────────
new_case help
out=$("$repo/bin/dot" --help 2>&1) || {
    fail "--help exits 0" "non-zero exit"
    out=
}
assert_contains "$out" "usage: dot" "--help prints usage"

out=$("$repo/bin/dot" -h 2>&1) || {
    fail "-h exits 0" "non-zero exit"
    out=
}
assert_contains "$out" "usage: dot" "-h prints usage"

if "$repo/bin/dot" --bogus >/dev/null 2>&1; then
    fail "unknown argument exits non-zero" "command unexpectedly succeeded"
else
    pass "unknown argument exits non-zero"
fi

# ── feature: default action and aliases ─────────────────────────────────────
new_case aliases
write_file "$repo/config/shared/.aliasrc" "x"
run_dot "$repo" "$target" >/dev/null 2>&1 || fail "default action (install) exits 0" "command failed"
assert_true "default action installs managed files" assert_link "$target/.aliasrc"

run_dot "$repo" "$target" uninstall >/dev/null 2>&1 || fail "uninstall alias exits 0" "command failed"
assert_true "uninstall alias removes managed symlink" assert_missing "$target/.aliasrc"

run_dot "$repo" "$target" dotfiles >/dev/null 2>&1 || fail "dotfiles alias exits 0" "command failed"
assert_true "dotfiles alias installs managed files" assert_link "$target/.aliasrc"

# ── feature: install links shared files ────────────────────────────────────
new_case install_basic
write_file "$repo/config/shared/.bashrc" "export A=1"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install basic exits 0" "command failed"
if assert_link "$target/.bashrc" 2>/dev/null; then
    got=$(readlink_target "$target/.bashrc" || printf '')
    want=$(CDPATH= cd -- "$repo/config/shared" && pwd -P)/.bashrc
    assert_eq "$want" "$got" "install links shared file to resolved source"
else
    fail "install links shared file" "target is not a symlink"
fi

# ── feature: layering override (later wins) ────────────────────────────────
new_case layering
os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]') || os=unknown
host=$(uname -n 2>/dev/null | sed 's/\..*//' | tr '[:upper:]' '[:lower:]') || host=unknown
[ -n "$os" ] || os=unknown
[ -n "$host" ] || host=unknown
write_file "$repo/config/shared/.config/app/conf" "shared"
write_file "$repo/config/env/common/.config/app/conf" "common"
write_file "$repo/config/env/$os/.config/app/conf" "os"
write_file "$repo/config/env/$host/.config/app/conf" "host"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install layering exits 0" "command failed"
got=$(readlink_target "$target/.config/app/conf" || printf '')
want=$(CDPATH= cd -- "$repo/config/env/$host" && pwd -P)/.config/app/conf
assert_eq "$want" "$got" "later layer overrides earlier (host wins)"

# ── feature: backup and restore on remove ──────────────────────────────────
new_case backup_restore
write_file "$repo/config/shared/.zshrc" "managed"
write_file "$target/.zshrc" "original"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install with existing file exits 0" "command failed"
if [ -f "$target/.zshrc.dotfiles.bak" ] || [ -L "$target/.zshrc.dotfiles.bak" ]; then
    pass "existing file is backed up on install"
else
    fail "existing file is backed up on install" "backup not found"
fi
run_dot "$repo" "$target" remove >/dev/null 2>&1 || fail "remove exits 0" "command failed"
if [ -f "$target/.zshrc" ] && [ ! -L "$target/.zshrc" ]; then
    content=$(cat "$target/.zshrc")
    assert_eq "original" "$content" "remove restores backup content"
else
    fail "remove restores backup file" "target missing or still symlink"
fi

# ── feature: idempotent install ────────────────────────────────────────────
new_case idempotent
write_file "$repo/config/shared/.profile" "x"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "first install exits 0" "command failed"
out1=$(run_dot "$repo" "$target" install 2>&1) || fail "second install exits 0" "command failed"
case $out1 in
*"link "*".profile"*) fail "idempotent install does not relink unchanged target" "unexpected relink output: $out1" ;;
*) pass "idempotent install does not relink unchanged target" ;;
esac

# ── feature: layer priority change relinks on reinstall ────────────────────
new_case relink_override
os=$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]') || os=unknown
[ -n "$os" ] || os=unknown
write_file "$repo/config/shared/.toolrc" "shared"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "initial install exits 0" "command failed"
got=$(readlink_target "$target/.toolrc" || printf '')
want=$(CDPATH= cd -- "$repo/config/shared" && pwd -P)/.toolrc
assert_eq "$want" "$got" "initial install links shared layer"

write_file "$repo/config/env/$os/.toolrc" "os"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "reinstall after higher-priority layer exits 0" "command failed"
got=$(readlink_target "$target/.toolrc" || printf '')
want=$(CDPATH= cd -- "$repo/config/env/$os" && pwd -P)/.toolrc
assert_eq "$want" "$got" "reinstall relinks to higher-priority layer source"

# ── feature: dry-run makes no changes ──────────────────────────────────────
new_case dry_run
write_file "$repo/config/shared/.gitconfig" "[user]"
run_dot "$repo" "$target" -n install >/dev/null 2>&1 || fail "dry-run install exits 0" "command failed"
if assert_missing "$target/.gitconfig"; then
    pass "dry-run install creates no symlink"
else
    fail "dry-run install creates no symlink" "target was created"
fi

# dry-run remove
new_case dry_run_remove
write_file "$repo/config/shared/.npmrc" "registry=example"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install before dry-run remove exits 0" "command failed"
out=$(run_dot "$repo" "$target" -n remove 2>&1) || fail "dry-run remove exits 0" "command failed"
assert_contains "$out" "dry-run:" "dry-run remove prints planned actions"
assert_true "dry-run remove leaves managed symlink in place" assert_link "$target/.npmrc"

# ── feature: remove without backup / multiple backups ──────────────────────
new_case remove_no_backup
write_file "$repo/config/shared/.editorconfig" "root=true"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install for no-backup remove exits 0" "command failed"
run_dot "$repo" "$target" remove >/dev/null 2>&1 || fail "remove without backup exits 0" "command failed"
assert_true "remove without backup deletes managed symlink" assert_missing "$target/.editorconfig"

new_case restore_latest_backup
write_file "$repo/config/shared/.testrc" "managed"
write_file "$target/.testrc" "original1"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "first install for backup chain exits 0" "command failed"
# Replace managed symlink with a new regular file to force a second backup on reinstall.
rm -f -- "$target/.testrc"
write_file "$target/.testrc" "original2"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "second install for backup chain exits 0" "command failed"
assert_true "first backup exists" assert_file "$target/.testrc.dotfiles.bak"
if [ -f "$target/.testrc.dotfiles.bak.1" ] || [ -L "$target/.testrc.dotfiles.bak.1" ]; then
    pass "second backup is versioned"
else
    fail "second backup is versioned" "expected .testrc.dotfiles.bak.1"
fi
run_dot "$repo" "$target" remove >/dev/null 2>&1 || fail "remove with backup chain exits 0" "command failed"
content=$(cat "$target/.testrc" 2>/dev/null || printf '')
assert_eq "original2" "$content" "remove restores newest backup"

# ── feature: repo symlink entries are ignored ──────────────────────────────
new_case ignore_repo_symlinks
write_file "$case_dir/outside" "outside"
ln -s -- "$case_dir/outside" "$repo/config/shared/.linked"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install with repo symlink exits 0" "command failed"
assert_true "symlink entries inside config layers are ignored" assert_missing "$target/.linked"

# ── safety: refuses to replace directory with file symlink ─────────────────
new_case refuse_dir
write_file "$repo/config/shared/.config/dirconf" "x"
mkdir -p -- "$target/.config/dirconf"
if run_dot "$repo" "$target" install >/dev/null 2>&1; then
    fail "refuses replacing directory with file symlink" "command unexpectedly succeeded"
else
    pass "refuses replacing directory with file symlink"
fi

# ── safety: refuses symlinked path component under target ──────────────────
new_case refuse_symlink_component
write_file "$repo/config/shared/.config/app/file" "x"
mkdir -p -- "$target/real"
ln -s -- "$target/real" "$target/.config"
if run_dot "$repo" "$target" install >/dev/null 2>&1; then
    fail "refuses traversing symlink path component under target" "command unexpectedly succeeded"
else
    pass "refuses traversing symlink path component under target"
fi

# ── safety: remove only managed links pointing into dotfiles ───────────────
new_case remove_scope
write_file "$repo/config/shared/.vimrc" "managed"
mkdir -p -- "$case_dir/other"
write_file "$case_dir/other/file" "other"
ln -s -- "$case_dir/other/file" "$target/.otherlink"
run_dot "$repo" "$target" install >/dev/null 2>&1 || fail "install for remove-scope exits 0" "command failed"
run_dot "$repo" "$target" remove >/dev/null 2>&1 || fail "remove for remove-scope exits 0" "command failed"
if assert_link "$target/.otherlink"; then
    pass "remove does not touch unrelated symlinks outside managed targets"
else
    fail "remove does not touch unrelated symlinks outside managed targets" "unrelated symlink changed"
fi

# ── bug tracker / known limitations (non-failing) ───────────────────────────
# Track known portability/behavior limitations without failing the suite.
# - Symlink targets are stored as resolved absolute paths (stable, but verbose).
# - Filenames containing newlines are unsupported due to line-based find|while.
skip "newline in filenames support" "known limitation: find|while read pipeline"

# ── summary ────────────────────────────────────────────────────────────────
log ""
log "Summary: $pass_count passed, $fail_count failed, $skip_count skipped"
if [ "$fail_count" -ne 0 ]; then
    exit 1
fi
exit 0

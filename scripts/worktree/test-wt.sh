#!/usr/bin/env bash
set -euo pipefail

WT="${WT:-/home/joaov/.dotfiles/config/shared/.local/bin/wt}"
TMPROOT="$(mktemp -d)"
trap 'rm -rf "$TMPROOT"' EXIT

pass=0
fail=0

assert_eq() {
  local name="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "ok - $name"
    pass=$((pass+1))
  else
    echo "not ok - $name"
    echo "  expected: $expected"
    echo "  actual:   $actual"
    fail=$((fail+1))
  fi
}

assert_contains() {
  local name="$1" haystack="$2" needle="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "ok - $name"
    pass=$((pass+1))
  else
    echo "not ok - $name"
    echo "  missing: $needle"
    echo "  in: $haystack"
    fail=$((fail+1))
  fi
}

new_repo() {
  local dir="$1"
  mkdir -p "$dir"
  git -C "$dir" init -q -b main
  git -C "$dir" config user.email test@example.com
  git -C "$dir" config user.name test
  echo hello > "$dir/file.txt"
  git -C "$dir" add file.txt
  git -C "$dir" commit -q -m init
}

export WT_BASE="$TMPROOT/wtbase"

# basic add/path/list/remove
REPO="$TMPROOT/repo"
new_repo "$REPO"
cd "$REPO"
out="$($WT add -b feat/a)"
assert_eq "add prints path" "$WT_BASE/repo/feat-a" "$out"
if test -d "$out"; then echo "ok - add created dir"; pass=$((pass+1)); else echo "not ok - add created dir"; fail=$((fail+1)); fi

out2="$($WT path feat/a)"
assert_eq "path returns path" "$WT_BASE/repo/feat-a" "$out2"

# idempotent add
out3="$($WT add -b feat/a 2>/dev/null)"
assert_eq "idempotent add returns path" "$WT_BASE/repo/feat-a" "$out3"

# list --status
status="$($WT list --status)"
assert_contains "list --status has branch" "$status" "feat/a"
assert_contains "list --status has clean" "$status" "clean"

# remove
rmout="$($WT remove feat/a)"
assert_contains "remove reports removed" "$rmout" "removed:"
if test ! -d "$WT_BASE/repo/feat-a"; then echo "ok - removed dir gone"; pass=$((pass+1)); else echo "not ok - removed dir gone"; fail=$((fail+1)); fi

# missing branch suggests -b
set +e
err="$($WT add no-such 2>&1 >/dev/null)"
rc=$?
set -e
assert_eq "add missing branch rc" "1" "$rc"
assert_contains "add missing branch hint" "$err" "wt add -b no-such"

# -b existing branch explains conflict
git -C "$REPO" branch feat/existing
set +e
err="$($WT add -b feat/existing 2>&1 >/dev/null)"
rc=$?
set -e
assert_eq "add -b existing rc" "1" "$rc"
assert_contains "add -b existing hint" "$err" "without -b"

# path missing suggests add/list
set +e
err="$($WT path nope 2>&1 >/dev/null)"
rc=$?
set -e
assert_eq "path missing rc" "1" "$rc"
assert_contains "path missing hint add" "$err" "wt add nope"
assert_contains "path missing hint list" "$err" "wt list"

# current/default/main worktree guard
set +e
err="$($WT remove main 2>&1 >/dev/null)"
rc=$?
set -e
assert_eq "remove main guarded rc" "1" "$rc"
assert_contains "remove main guarded msg" "$err" "refusing to remove"

# init-shell
bashwrap="$($WT init-shell bash)"
assert_contains "init-shell bash has wt()" "$bashwrap" "wt()"
zshwrap="$($WT init-shell zsh)"
assert_contains "init-shell zsh has wt()" "$zshwrap" "wt()"
fishwrap="$($WT init-shell fish)"
assert_contains "init-shell fish has function wt" "$fishwrap" "function wt"

# collision detection: feat/collision-a sanitizes to feat-collision-a
$WT add -b feat/collision-a >/dev/null
set +e
err="$($WT add -b feat-collision-a 2>&1 >/dev/null)"
rc=$?
set -e
assert_eq "collision rc" "1" "$rc"
assert_contains "collision msg" "$err" "collision"

# space in repo path: porcelain fallback/remove should handle spaces
SPACEREPO="$TMPROOT/my repo"
new_repo "$SPACEREPO"
cd "$SPACEREPO"
$WT add -b space/branch >/dev/null
rmout="$($WT remove space/branch)"
assert_contains "remove space repo" "$rmout" "removed:"

# space in path porcelain fallback: worktree at custom path with spaces
SPACEREPO2="$TMPROOT/my repo2"
new_repo "$SPACEREPO2"
cd "$SPACEREPO2"
mkdir -p "$TMPROOT/custom dir"
git -C "$SPACEREPO2" worktree add -b space/fallback "$TMPROOT/custom dir/wt" >&2
rmout="$($WT remove space/fallback)"
assert_contains "remove space fallback" "$rmout" "removed:"
if test ! -d "$TMPROOT/custom dir/wt"; then echo "ok - space fallback removed"; pass=$((pass+1)); else echo "not ok - space fallback removed"; fail=$((fail+1)); fi

# refuse removing current worktree (linked)
cd "$REPO"
$WT add -b feat/current-test >/dev/null
cd "$WT_BASE/repo/feat-current-test"
set +e
err="$($WT remove feat/current-test 2>&1 >/dev/null)"
rc=$?
set -e
assert_eq "remove current worktree rc" "1" "$rc"
assert_contains "remove current worktree msg" "$err" "current worktree"
cd "$REPO"
$WT remove feat/current-test >/dev/null

# list --status shows dirty
$WT add -b feat/dirty >/dev/null
echo dirty > "$WT_BASE/repo/feat-dirty/dirty.txt"
status="$($WT list --status)"
assert_contains "list --status dirty" "$status" "dirty"
$WT remove -f feat/dirty >/dev/null

# prune
cd "$REPO"
$WT prune >/dev/null
echo "ok - prune runs"
pass=$((pass+1))

echo ""
echo "PASS: $pass FAIL: $fail"
[[ $fail -eq 0 ]]

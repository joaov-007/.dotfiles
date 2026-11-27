#!/usr/bin/env bash
set -euo pipefail

WT="${WT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/config/shared/.local/bin/wt}"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export WT_BASE="$tmp/wtbase"

pass=0; fail=0
t() { local name="$1"; shift; if "$@"; then echo "ok - $name"; pass=$((pass+1)); else echo "not ok - $name"; fail=$((fail+1)); fi; }
expect_fail() { local name="$1"; shift; if "$@" >/tmp/wt_smoke_out 2>/tmp/wt_smoke_err; then echo "not ok - $name (expected failure)"; fail=$((fail+1)); else echo "ok - $name"; pass=$((pass+1)); fi; }
has() { grep -Fq -- "$1" "$2"; }

mkdir -p "$tmp/repo" && cd "$tmp/repo"
git init -q
git config user.email test@test
git config user.name test
echo hi >f; git add f; git commit -q -m init
main_branch=$(git symbolic-ref --short HEAD)
git branch feature/a
git branch existing-no-wt

# P0: add/path/remove basics
p=$("$WT" add feature/a 2>/tmp/wt_smoke_err)
t "add returns path" test "$p" = "$WT_BASE/repo/feature-a"
t "add creates dir" test -d "$p"
t "add stdout clean" test "$(printf '%s\n' "$p" | wc -l | tr -d ' ')" = "1"

# P1: idempotent add
p2=$("$WT" add feature/a 2>/tmp/wt_smoke_err2)
t "idempotent add path" test "$p2" = "$p"
t "idempotent add hint" has "already exists" /tmp/wt_smoke_err2

# P1: missing branch suggests -b; -b existing branch explains conflict
expect_fail "missing branch fails" "$WT" add no-such
t "missing branch suggests -b" has "wt add -b" /tmp/wt_smoke_err
expect_fail "add -b existing branch fails" "$WT" add -b existing-no-wt
t "add -b conflict message" has "already exists" /tmp/wt_smoke_err

# P0/P1: path checks existence
"$WT" path feature/a >/tmp/wt_smoke_out
t "path returns existing" test "$(cat /tmp/wt_smoke_out)" = "$p"
expect_fail "path missing fails" "$WT" path does-not-exist
t "path missing suggests" has "wt add" /tmp/wt_smoke_err

# P1: list --status
"$WT" list --status >/tmp/wt_smoke_list
t "list --status has branch" has "feature-a" /tmp/wt_smoke_list
t "list --status has clean" has "clean" /tmp/wt_smoke_list
echo changed > "$p/f"
"$WT" list --status >/tmp/wt_smoke_list
t "list --status has dirty" has "dirty" /tmp/wt_smoke_list
git -C "$p" checkout -- f >/dev/null 2>&1 || true

# P0: remove guards
expect_fail "remove main refused" "$WT" remove "$main_branch"
t "main refusal message" has "main worktree" /tmp/wt_smoke_err
cd "$p"
expect_fail "remove . refused" "$WT" remove .
t "remove . refused message" has "current worktree" /tmp/wt_smoke_err
cd "$tmp/repo"

# dirty remove needs -f
echo dirty > "$p/g"
expect_fail "remove dirty fails" "$WT" remove feature/a
t "dirty suggests -f" has "remove -f" /tmp/wt_smoke_err
"$WT" remove -f feature/a >/tmp/wt_smoke_out
t "force remove ok" has "removed:" /tmp/wt_smoke_out
t "removed dir gone" test ! -d "$p"

# P0: porcelain space fallback
git branch "space/branch"
git worktree add "$tmp/wtbase/repo/space branch" "space/branch" >/dev/null 2>&1
"$WT" remove "space/branch" >/tmp/wt_smoke_out
t "remove path-with-space fallback" has "removed:" /tmp/wt_smoke_out

# P0: sanitized collision
git branch feature/z
git branch feature-z
"$WT" add feature/z >/dev/null 2>&1
expect_fail "sanitized collision fails" "$WT" add feature-z
t "collision message" has "path collision" /tmp/wt_smoke_err

# P1: init-shell
"$WT" init-shell bash >/tmp/wt_smoke_sh
t "init-shell bash" has "wt()" /tmp/wt_smoke_sh
"$WT" init-shell zsh >/tmp/wt_smoke_sh
t "init-shell zsh" has "wt()" /tmp/wt_smoke_sh
"$WT" init-shell fish >/tmp/wt_smoke_sh
t "init-shell fish" has "function wt" /tmp/wt_smoke_sh
expect_fail "init-shell bad" "$WT" init-shell tcsh

echo "pass=$pass fail=$fail"
test "$fail" -eq 0

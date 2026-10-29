#!/usr/bin/env bash
# wt — create, list, merge and remove git worktrees in any repository.
#
# Worktrees live in a per-repository directory under a single root, so the
# same helper works for every project:
#
#   wt new feat/login main  ->  ~/.worktrees/myapp/feat-login
#   cd "$(wt path feat/login)"
#   wt merge feat/login     ->  ff-merge into the current branch, clean up
#
# The root can be overridden per call (--root), per shell (WORKTREE_ROOT)
# or per repository (git config worktree.root DIR).
set -euo pipefail

PROG=${0##*/}
DEFAULT_ROOT=$HOME/.worktrees
REPO_ROOT=
ROOT_OVERRIDE=

die() {
	printf '%s: %s\n' "$PROG" "$*" >&2
	exit 1
}

usage() {
	cat <<USAGE
Usage: $PROG [--root DIR] <command> [args]

Commands:
  new <branch> [base]   Create a worktree for <branch> from <base>
                        (default: current branch). An existing branch is
                        checked out instead of being recreated.
  list                  List the worktrees of the current repository.
  path <branch>         Print the worktree directory for <branch>.
  merge <branch> [--force] [--rebase] [--squash]
                        Integrate <branch> into the current branch, then
                        remove its worktree and delete the branch.
                        Default: fast-forward only. --rebase rebases
                        <branch> onto the current branch before merging.
                        --squash performs a squash merge (commits changes).
                        --force discards local changes in that worktree.
  remove <branch> [--force] [--delete-branch]
                        Remove the worktree. --delete-branch also deletes
                        the local branch, but only if it is merged.
  prune                 Drop metadata for worktrees deleted by hand.
  help                  Show this help.

Options:
  --root DIR            Worktree root for this call. Defaults to
                        \$WORKTREE_ROOT, then \`git config worktree.root',
                        then ~/.worktrees.

Layout: <root>/<repository>/<branch with / replaced by ->

Examples:
  $PROG new feat/login main
  cd "\$($PROG path feat/login)"
  $PROG merge feat/login
USAGE
}

repo_root() {
	if [[ -n $REPO_ROOT ]]; then
		printf '%s\n' "$REPO_ROOT"
		return
	fi
	REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null) ||
		die "not inside a git repository"
	printf '%s\n' "$REPO_ROOT"
}

expand_tilde() {
	local path=${1:-}
	if [[ $path == '~' ]]; then
		path=$HOME
	elif [[ ${path:0:1} == '~' && ${path:1:1} == '/' ]]; then
		path=$HOME/${path:2}
	fi
	printf '%s\n' "$path"
}

worktree_root() {
	local root=
	if [[ -n $ROOT_OVERRIDE ]]; then
		root=$ROOT_OVERRIDE
	elif [[ -n ${WORKTREE_ROOT:-} ]]; then
		root=$WORKTREE_ROOT
	else
		root=$(git -C "$(repo_root)" config --get worktree.root || true)
		[[ -n $root ]] || root=$DEFAULT_ROOT
	fi
	root=$(expand_tilde "$root")
	case $root in
	/*) ;;
	*) root=$PWD/$root ;;
	esac
	printf '%s\n' "$root"
}

worktree_dir() {
	local branch=$1 root repo
	root=$(worktree_root)
	repo=$(basename "$(repo_root)")
	printf '%s/%s/%s\n' "$root" "$repo" "${branch//\//-}"
}

cmd_new() {
	local branch=${1:-} base=${2:-}
	[[ -n $branch ]] || die "branch name required (see '$PROG help')"
	[[ $# -le 2 ]] || die "usage: $PROG new <branch> [base]"

	local repo dir
	repo=$(repo_root)
	git check-ref-format "refs/heads/$branch" >/dev/null 2>&1 ||
		die "invalid branch name: $branch"

	dir=$(worktree_dir "$branch")
	[[ -e $dir ]] && die "worktree directory already exists: $dir"

	mkdir -p "$(dirname "$dir")"
	if git -C "$repo" show-ref --verify --quiet "refs/heads/$branch"; then
		echo "Checking out existing branch $branch"
		git -C "$repo" worktree add "$dir" "$branch"
	else
		base=${base:-$(git -C "$repo" symbolic-ref --quiet --short HEAD || echo HEAD)}
		git -C "$repo" rev-parse --verify --quiet "$base^{commit}" >/dev/null ||
			die "unknown base: $base"
		echo "Creating branch $branch from $base"
		git -C "$repo" worktree add -b "$branch" "$dir" "$base"
	fi
	echo "Worktree: $dir"
}

cmd_list() {
	[[ $# -eq 0 ]] || die "usage: $PROG list"
	git -C "$(repo_root)" worktree list
}

cmd_path() {
	local branch=${1:-}
	[[ -n $branch ]] || die "branch name required (see '$PROG help')"
	[[ $# -eq 1 ]] || die "usage: $PROG path <branch>"
	worktree_dir "$branch"
}

cmd_merge() {
	local branch=${1:-} force=0 strategy=ff
	[[ -n $branch ]] || die "branch name required (see '$PROG help')"
	shift || true
	while (($#)); do
		case $1 in
		-f | --force) force=1 ;;
		--rebase) strategy=rebase ;;
		--squash) strategy=squash ;;
		*) die "usage: $PROG merge <branch> [--force] [--rebase] [--squash]" ;;
		esac
		shift
	done

	local repo current dir
	repo=$(repo_root)
	current=$(git -C "$repo" symbolic-ref --quiet --short HEAD) ||
		die "detached HEAD: check out a branch before merging"
	[[ $branch != "$current" ]] || die "cannot merge $branch into itself"
	git -C "$repo" rev-parse --verify --quiet "refs/heads/$branch" >/dev/null ||
		die "no local branch: $branch"

	case $strategy in
	ff)
		echo "Merging $branch into $current (fast-forward only)"
		git -C "$repo" merge --ff-only "$branch"
		;;
	rebase)
		echo "Rebasing $branch onto $current"
		git -C "$repo" rebase "$current" "$branch"
		git -C "$repo" checkout "$current"
		echo "Merging $branch into $current (fast-forward)"
		git -C "$repo" merge --ff-only "$branch"
		;;
	squash)
		echo "Squash merging $branch into $current"
		git -C "$repo" merge --squash "$branch"
		git -C "$repo" commit
		;;
	*) die "unknown merge strategy: $strategy" ;;
	esac

	dir=$(worktree_dir "$branch")
	if [[ -d $dir ]]; then
		if ((force)); then
			git -C "$repo" worktree remove --force "$dir"
		else
			git -C "$repo" worktree remove "$dir"
		fi
		echo "Removed worktree: $dir"
	fi
	if [[ $strategy == squash ]]; then
		git -C "$repo" branch -D "$branch"
	else
		git -C "$repo" branch -d "$branch"
	fi
}

cmd_remove() {
	local branch=${1:-}
	[[ -n $branch ]] || die "branch name required (see '$PROG help')"
	shift || true

	local force=0 delete_branch=0
	while (($#)); do
		case $1 in
		-f | --force) force=1 ;;
		-d | --delete-branch) delete_branch=1 ;;
		*) die "usage: $PROG remove <branch> [--force] [--delete-branch]" ;;
		esac
		shift
	done

	local repo dir
	repo=$(repo_root)
	dir=$(worktree_dir "$branch")
	[[ -d $dir ]] || die "no worktree directory at $dir"

	if ((force)); then
		git -C "$repo" worktree remove --force "$dir"
	else
		git -C "$repo" worktree remove "$dir"
	fi
	echo "Removed worktree: $dir"

	if ((delete_branch)); then
		git -C "$repo" branch -d "$branch"
	else
		echo "Branch $branch kept (use --delete-branch to remove it)"
	fi
}

cmd_prune() {
	[[ $# -eq 0 ]] || die "usage: $PROG prune"
	git -C "$(repo_root)" worktree prune -v
}

main() {
	while (($#)); do
		case $1 in
		--root)
			[[ $# -ge 2 ]] || die "--root needs a directory"
			ROOT_OVERRIDE=$2
			shift 2
			;;
		--root=*)
			ROOT_OVERRIDE=${1#--root=}
			[[ -n $ROOT_OVERRIDE ]] || die "--root needs a directory"
			shift
			;;
		-h | --help)
			usage
			exit 0
			;;
		--)
			shift
			break
			;;
		-*)
			die "unknown option: $1 (see '$PROG help')"
			;;
		*)
			break
			;;
		esac
	done

	local cmd=${1:-help}
	shift || true
	case $cmd in
	new) cmd_new "$@" ;;
	list) cmd_list "$@" ;;
	path) cmd_path "$@" ;;
	merge) cmd_merge "$@" ;;
	remove) cmd_remove "$@" ;;
	prune) cmd_prune "$@" ;;
	help | --help | -h) usage ;;
	*) die "unknown command '$cmd' (see '$PROG help')" ;;
	esac
}

main "$@"

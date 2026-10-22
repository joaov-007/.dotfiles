#!/usr/bin/env bash
# Manage git worktrees for atomic, conventional-commit style changes to this repo
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $(basename "$0") <command> [args]

Commands:
  new <branch> [base]  Create a new worktree for <branch> under ~/.dotfiles-worktrees/
                       base defaults to current branch
  merge <branch>       Fast-forward merge <branch> into current branch, then remove worktree
  list                 List existing worktrees
  help                 Show this help

Examples:
  $(basename "$0") new feat/my-change dev
  $(basename "$0") merge feat/my-change
USAGE
}

WORKTREE_ROOT="${HOME}/.dotfiles-worktrees"

cmd_new() {
  local branch="${1:-}"
  local base="${2:-$(git -C "$(git rev-parse --show-toplevel)" branch --show-current)}"
  if [[ -z "$branch" ]]; then
    echo "error: branch name required" >&2
    usage >&2
    exit 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  local repo_name
  repo_name="$(basename "$repo_root")"
  local wt_dir="${WORKTREE_ROOT}/${repo_name}-${branch//\//-}"

  mkdir -p "$WORKTREE_ROOT"
  if [[ -d "$wt_dir" ]]; then
    echo "error: worktree already exists: $wt_dir" >&2
    exit 1
  fi

  echo "Creating worktree: $wt_dir"
  echo "  branch: $branch (from $base)"
  git -C "$repo_root" worktree add -b "$branch" "$wt_dir" "$base"
  echo "Done. cd $wt_dir"
}

cmd_merge() {
  local branch="${1:-}"
  if [[ -z "$branch" ]]; then
    echo "error: branch name required" >&2
    usage >&2
    exit 1
  fi

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"
  local current
  current="$(git -C "$repo_root" branch --show-current)"

  local repo_name
  repo_name="$(basename "$repo_root")"
  local wt_dir="${WORKTREE_ROOT}/${repo_name}-${branch//\//-}"

  echo "Merging $branch into $current (fast-forward only)"
  git -C "$repo_root" merge --ff-only "$branch"
  echo "Merged. Cleaning up worktree..."
  if [[ -d "$wt_dir" ]]; then
    git -C "$repo_root" worktree remove "$wt_dir" --force
    git -C "$repo_root" branch -d "$branch" 2>/dev/null || git -C "$repo_root" branch -D "$branch"
  fi
  echo "Done."
}

cmd_list() {
  git worktree list
}

main() {
  local cmd="${1:-help}"
  shift || true
  case "$cmd" in
    new) cmd_new "$@" ;;
    merge) cmd_merge "$@" ;;
    list) cmd_list "$@" ;;
    help|--help|-h) usage ;;
    *) echo "error: unknown command '$cmd'" >&2; usage >&2; exit 1 ;;
  esac
}

main "$@"

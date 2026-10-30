---
title: Git Worktree Helper
description: "wt, the repo-agnostic git worktree wrapper that keeps checkouts under one root"
tags:
  - git
  - worktrees
  - tooling
type: note
status: evergreen
created: 2026-10-28
updated: 2026-10-28
language: en
audience: maintainer
scope: day-to-day git worktree workflow across repositories
keywords:
  - git
  - worktree
  - wt
  - branch
platform:
  - Arch Linux
related:
  - "[[development|Development & Tooling]]"
cssclasses:
  - note
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Document the generic git worktree helper rewritten from the dotfiles-specific script"
ai-review: pending
last_reviewed: 2026-10-28
review_after: 2027-04-28
---

# Git Worktree Helper

`wt` wraps `git worktree` so that every repository puts its extra checkouts in
the same place, under one root. It works from any repo; nothing is tied to
`~/.dotfiles`.

## Source and symlink

- Script: `~/.dotfiles/scripts/git/worktree.sh`
- Command: `~/.local/bin/wt` (symlink into the dotfiles checkout)

On a fresh machine:

```bash
ln -sfn ~/.dotfiles/scripts/git/worktree.sh ~/.local/bin/wt
```

`~/.local/bin` is already on `PATH` via `zsh/.config/zsh/00-paths.zsh`.

## Layout

```text
<root>/<repository>/<branch with / replaced by ->
```

```text
~/.worktrees/myapp/feat-login
~/.worktrees/api/hotfix-1.2
```

The root is resolved in this order:

1. `--root DIR` on the command line
2. `WORKTREE_ROOT` environment variable
3. `git config worktree.root DIR` for the current repository
4. `~/.worktrees`

A relative root is resolved against the current directory; `~/` is expanded.
The same root has to be used on every command for a given branch, otherwise
`merge` and `remove` will not find the worktree.

## Commands

| Command | Effect |
| --- | --- |
| `wt new <branch> [base]` | Creates the worktree. A missing branch is created from `base` (default: current branch); an existing branch is checked out as-is. |
| `wt list` | `git worktree list` for the current repository. |
| `wt path <branch>` | Prints the worktree directory, for `cd "$(wt path ...)"`. |
| `wt merge <branch>` | `--ff-only` merge into the current branch, removes the worktree, deletes the branch. `--force` discards local changes in that worktree. |
| `wt remove <branch>` | Removes the worktree, keeps the branch. `--delete-branch` also deletes it with `git branch -d`. `--force` discards local changes. |
| `wt prune` | Drops metadata for worktrees deleted by hand. |

## Typical flow

```bash
cd ~/src/myapp
wt new feat/login main
cd "$(wt path feat/login)"

# ... edit, commit ...

cd ~/src/myapp
wt merge feat/login
```

Working on a branch that already exists:

```bash
git branch hotfix/session-expiry origin/main
wt new hotfix/session-expiry
```

## Safety behaviour

- `new` refuses an existing directory and validates the branch name, so a
  typo cannot reuse another branch's checkout.
- `merge` is fast-forward only. A merge that needs a real merge commit stops
  and leaves the branch in place.
- `merge` and `remove` refuse a dirty worktree. Nothing is thrown away unless
  `--force` is passed.
- `remove` uses `git branch -d`, so an unmerged branch is never deleted by
  accident.
- `prune` is the cleanup path after deleting a worktree directory with `rm`.

## Related

- `opencode-worktree` (installed separately in `~/.local/bin`) is an
  interactive TUI over the same `git worktree` primitives. `wt` is the
  scriptable terminal version.
- [[development|Development & Tooling]]

---
title: Git Worktree Helper
description: "wt, the repo-agnostic git worktree wrapper for creating, listing, and removing worktrees"
tags:
  - git
  - worktrees
  - tooling
type: note
status: evergreen
created: 2026-10-28
updated: 2026-11-27
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
ai-model: "gpt-5.4"
ai-provider: "openai"
ai-prompt: "Update git worktree helper doc after deduplicating old worktree.sh into wt"
ai-review: pending
last_reviewed: 2026-11-27
review_after: 2027-05-27
---

# Git Worktree Helper

`wt` wraps `git worktree` so that every repository keeps its extra checkouts
under one root. It works from any repo.

## Source

- Canonical script: `~/.dotfiles/config/shared/.local/bin/wt`
- Installed copy: `~/.local/bin/wt` (keep in sync with canonical script)

`~/.local/bin` is on `PATH` via `config/.config/shell/env.sh`.

## Layout

```text
$WT_BASE/<project-name>/<sanitized-branch>
```

Default base: `~/.cache/git` (override with `WT_BASE`).

## Commands

| Command | Effect |
| --- | --- |
| `wt add [-b] <branch> [<start-point>]` | Add worktree for branch. Idempotent if it already exists; prints path. |
| `wt list [--status]` | List worktrees. `--status` adds local dirty/locked/prunable info. |
| `wt remove [-f] <branch>` | Remove worktree for branch. Refuses current/default worktree by default. |
| `wt prune [-f]` | Prune stale worktree metadata. `-f` expires now. |
| `wt path <branch>` | Print worktree path for branch. |
| `wt cd <branch>` | Alias for `path`. |
| `wt init-shell <bash\|zsh\|fish>` | Print shell wrapper for auto-cd on `wt cd`. |

## Typical flow

```bash
cd ~/src/myapp
wt add -b feat/login main
cd "$(wt path feat/login)"

# ... edit, commit ...

cd ~/src/myapp
wt remove feat/login
```

For auto-cd support, add to your shell config:

```bash
eval "$(wt init-shell bash)"
```

## Safety behaviour

- `add` validates branch args, detects sanitized-path collisions, and gives actionable hints when a branch is missing or `-b` conflicts.
- `remove` refuses removing the current or default/main worktree by default; `-f` is explicit force.
- `path/cd` report missing worktrees and suggest `wt add` / `wt list`.
- stdout is for machine-usable paths/list output; stderr is for hints/errors.

## Tests

```bash
shellcheck -x -S style config/shared/.local/bin/wt scripts/worktree/test-wt.sh
bash scripts/worktree/test-wt.sh
```

## Related

- [[development|Development & Tooling]]

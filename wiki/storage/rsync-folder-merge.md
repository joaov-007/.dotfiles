---
title: rsync folder merge
description: "How to safely merge two folders with rsync: dry-run first, then copy, then verify."
tags:
  - linux
  - arch
  - storage
  - setup
type: guide
status: draft
created: 2026-09-27
updated: 2026-10-12
related:
  - arch-setup
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document rsync folder merge procedure"
ai-review: pending
language: en
audience: sysadmin
scope: merging two folder trees with rsync
keywords:
  - rsync
  - merge
  - backup
  - checksum
platform:
  - Linux
  - POSIX shell
cssclasses:
  - nota-longa
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# rsync folder merge

`rsync` copies files between folders and only transfers what changed, which makes
it the right tool for merging: new files appear, matching files are left alone,
and you can preview everything before touching disk. It is already in the base
install — see `arch-setup.md`, section 2.

Nothing on this page has been run against a live merge. It is documentation only.

---

## The basic idea

Merge folder `B` into folder `A` means: everything in `B` ends up in `A`, and
files that exist in both are resolved by a rule you choose. Nothing is deleted
from `B`.

```
A/  +  B/  ->  A/
```

---

## 1. Dry run — see what would happen

```bash
rsync -avun B/ A/
```

| Flag | Meaning |
|---|---|
| `-a` | Archive mode: recursive, preserves permissions, timestamps, symlinks |
| `-v` | Verbose — list every file |
| `-u` | Skip files that are newer on the receiver (A) |
| `-n` | **Dry run** — no changes are made |

Read the output carefully. Every line shown is a file that *would* be copied.
If the list looks wrong, stop here.

---

## 2. Real merge — copy B into A

```bash
rsync -avu B/ A/
```

Same flags minus `-n`. This is safe:

- Files only in `B` are copied to `A`.
- Files in both with different content are copied if the `B` version is newer.
- Files already in `A` that are newer are left untouched.
- `B` is never modified.

---

## 3. Verify the merge

```bash
# Compare the two folders — should report no differences
diff -r A/ B/

# Or a quick file-count sanity check
echo "A: $(find A/ -type f | wc -l) files"
echo "B: $(find B/ -type f | wc -l) files"
```

`diff -r` exits non-zero and prints any files that differ. A clean run means the
merge is good.

---

## Common variations

### Overwrite everything in A with B's version

```bash
rsync -av --ignore-existing B/ A/   # never overwrite A
rsync -av --delete B/ A/           # make A an exact mirror of B (DESTRUCTIVE)
```

> **`--delete` is dangerous.** It removes files in `A` that are not in `B`.
> Always dry-run with `-n --delete` first and read the output.

### Merge two folders into a third

```bash
mkdir merged
rsync -avu A/ merged/
rsync -avu B/ merged/
```

No risk to the originals. Clean up with `rm -rf A B` once `merged/` is verified.

### Only merge specific file types

```bash
rsync -avu --include='*/' --include='*.md' --exclude='*' B/ A/
```

Copies only Markdown files, but traverses all subdirectories to find them.

---

## Troubleshooting

**`rsync: command not found`**

```bash
sudo pacman -S --needed --noconfirm rsync
```

**Permissions denied on files in A**

Run with `sudo` or ensure you own the destination:

```bash
rsync -avu --no-perms --no-owner --no-group B/ A/
```

Useful when merging across users or into a system path.

**Timestamps look wrong after merge**

Add `-t` (included in `-a`) to preserve modification times. Without it, copied
files get the current time, which breaks tools that rely on mtime.

**Symlinks are copied as symlinks, not followed**

`-a` preserves symlinks. To dereference (copy the target file instead), add `-L`:

```bash
rsync -avuL B/ A/
```

---

## Rollback

`rsync` without `--delete` never destroys data in `A`. The worst case is a file
overwritten by a newer `B` version. Recover with:

```bash
# See what changed (if you have a backup or snapshot of A)
diff -r A/ /path/to/backup/A/

# Or use btrfs snapshots if A is on a subvolume
btrfs subvolume snapshot /path/to/A /path/to/A-snap
```

If you used `--delete` and did not dry-run first, recovery depends on backups,
snapshots, or filesystem-level undo (btrfs/ZFS). This is why the dry-run is not
optional.

---

## The short version

```bash
# 1. Preview
rsync -avun B/ A/

# 2. Merge
rsync -avu B/ A/

# 3. Verify
diff -r A/ B/
```

Three commands. Dry run first, then copy, then verify. That is the whole
workflow.

## Related

- `arch-setup.md` — rsync is installed in the base pacman set, section 2

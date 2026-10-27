---
title: "Finding and Working on Linux Kernel Development Tasks"
aliases:
  - kernel-tasks
  - kernel-dev-tasks
  - linux-kernel-contribution
description: >
  How to find, evaluate, and work on Linux kernel development tasks.
  A guide for helping other developers and improving development quality.
tags:
  - linux
  - kernel
  - development
  - contribition
  - workflow
type: guide
status: evergreen
created: 2026-10-25
updated: 2026-10-25
review_after: 2027-04-25
language: en
audience: developer
scope: tasks and workflows for Linux kernel contribution and quality improvement
platform:
  - Linux
  - Any architecture
keywords:
  - kernel
  - contribution
  - debugging
  - documentation
  - testing
sources:
  - "The Linux Kernel Documentation: how-to-help"
  - "Kernel Newbies: KernelJanitors/Todo"
  - "LKML submission process guides"
related:
  - "[[kernel-initramfs]]"
  - "[[kernel-dev-debugging]]"
cssclasses:
  - reference
---
# Finding and Working on Linux Kernel Development Tasks

> [!summary]
> This guide outlines where and how to find meaningful tasks in the Linux kernel
> project, how to evaluate them for your skill level, and how to contribute
> effectively while improving overall development quality.

## Why Contribute to the Linux Kernel?

The Linux kernel powers most of the world's infrastructure — from phones to supercomputers.
Contributing improves:

- **Your skills** — understanding OS internals, C systems programming, and git workflows
- **The ecosystem** — better hardware support, bug fixes, security improvements
- **Other developers** — clearer documentation, fewer build warnings, easier debugging
- **Your career** — visible contributions, maintainer recognition, networking

## Where to Find Tasks

### 1. **Official TODO Lists**

| Location | What you'll find | Effort level |
|---|---|---|
| `Documentation/todo.rst` (kernel root) | High-level documentation gaps, warning fixes, ancient docs | Beginner-friendly |
| `Documentation/filesystems/cifs/todo.html` | Subsystem-specific missing features, contributions welcome | Intermediate |
| `Documentation/doc-guide/contributing.html` | Documentation TODO list from the maintainers | All levels |
| Subsystem maintainers' emails | `scripts/get_maintainer.pl` will show you who to contact | Advanced |

### 2. **Kernel Newbies & Janitor Tasks**

- **KernelNewbies.org/KernelJanitors/Todo** — Tasks specifically marked as beginner-friendly
- **Good first bug** tags on LKML patches
- **Label**: `label: "good first patch"` or `label: "beginner-friendly"` on patchwork instances

### 3. **LKML and Patchwork**

- **patchwork.kernel.org** — Browse patches needing review, testing, or review
- **LKML mailing list** — Read `net`, `scsi`, `mm`, `usb` threads for recurring issues
- **Search pattern**: `"help needed" OR "review needed" OR "testing needed"`

### 4. **Build Warning Hunts**

Run `make htmldocs` or `make refcheckdocs` in the kernel tree and fix warnings.
This is one of the highest-impact activities for improving development quality.

### 5. **Unused Kerneldoc Comments**

Run `tools/docs/find-unused-docs.sh` from the kernel source to find comments
that should be pulled into the documentation build.

## How to Evaluate a Task

### Check Your Skills Match

| Task type | Required skills | Estimated time |
|---|---|---|
| Typo fixes | Markdown, attention to detail | 15-30 min |
| Warning fixes | C, kerneldoc format, Sphinx/build system | 1-3 hours |
| Kerneldoc additions | C, function semantics, documentation | 2-4 hours |
| TODO item creation | Subsystem knowledge, problem description | 3-6 hours |
| Feature documentation | Deep subsystem understanding, user scenarios | 1+ day |

### Ask These Questions

1. **Is this task still relevant?** — Some TODOs are from old kernel versions
2. **Do I have the context?** — Can I understand the code involved?
3. **Is there a maintainer?** — Use `scripts/get_maintainer.pl <file>` to find out
4. **What's the expected outcome?** — A patch, a documented feature, a fixed warning?

## How to Work on Tasks Effectively

### 1. **Start Small**

- Fix a documentation typo
- Clean up a kerneldoc comment
- Address one build warning
- These build momentum and familiarity with the process

### 2. **Follow the Submission Process**

1. **Clone the kernel**: `git clone --depth 1 -b master https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ~/linux/`
2. **Create a topic branch**: `git checkout -b docs/my-task-fix`
3. **Make your changes** — follow the existing style
4. **Test your changes** — `make htmldocs` for docs, `make refcheckdocs` for references
5. **Submit**: `git format-patch -1` and send to `linux-kernel@vger.kernel.org` or the maintainer

### 3. **Use the Right Tools**

- `scripts/get_maintainer.pl` — Find the right maintainer for your change
- `scripts/checkpatch.pl` — Verify your patch style matches kernel requirements
- `git log --oneline --graph --all` — Understand the history and context
- `make localmodconfig` — Create a minimal config for testing

### 4. **Engage with the Community**

- **LKML** — Read the list before posting; follow etiquette
- **CC maintainers** — Use `get_maintainer.pl` to add proper CCs
- **Be responsive** — Answer questions on your patch promptly
- **Accept feedback** — Patches often go through multiple revisions

## Improving Development Quality

### Code Quality

- **Run `checkpatch.pl`** on every patch — it catches style and semantic issues
- **Use `sparse`** for static analysis: `make C=1` (check for common errors)
- **Enable warnings** — `make C=2` for stricter checking

### Documentation Quality

- **Eliminate warnings** — they obscure real problems
- **Write testable kerneldoc** — use the specification format from `Documentation/doc-guide/code-specifications.rst`
- **Keep TODOs updated** — remove completed items, add new relevant ones

### Testing Quality

- **Boot with `-s -S`** and attach GDB for kernel debugging workflows
- **Run relevant xfstests** for filesystem changes
- **Use `kselftest`** for core kernel self-tests: `make ksellftest`
- **Test with different configs** — `DEBUG`, `PROVE`, `KASAN` builds

## Getting Started Today

### 15-Minute Start

```bash
# 1. Find the kernel tree
git clone --depth 1 -b master \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ~/linux/

# 2. Run the documentation build
make htmldocs 2>&1 | head -50

# 3. Fix the first warning you see
#    (follow the format: filename:line: warning: message)
```

### First Contribution Workflow

```bash
# 1. Find a TODO or warning
cd ~/linux
./scripts/get_maintainer.pl Documentation/todo.rst

# 2. Create a branch and fix
git checkout -b docs/fix-todo
# ... make changes ...

# 3. Submit
git format-patch -1
# Send the .patch file to the maintainer identified above
```

## Related Resources

- `[[kernel-dev-debugging]]` — GDB debugging workflow for kernel development
- `[[arch-linux/kernel-dev-debugging]]` — Arch-specific kernel debugging setup
- `[[Vault Conventions]]` — This vault's schema and tag taxonomy
- [Kernel Newbies: How to Contribute](https://kernelnewbies.org/How_to_contribute/)
- [LWN.net: Kernel contribution guide](https://lwn.net/Articles/...)

> [!tip]
> Start with documentation fixes — they have the lowest barrier to entry,
> provide immediate visible improvement, and teach you the most about
> the kernel's code and contribution process.
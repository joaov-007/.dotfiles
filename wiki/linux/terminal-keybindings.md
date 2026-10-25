---
title: "Terminal Keybindings"
aliases:
  - Terminal shortcuts
  - Readline keybindings
  - Bash keybindings
  - Zsh keybindings
  - Shell control keys
  - Ctrl key cheat sheet
  - Terminal cheat sheet
description: >-
  Cheat sheet of terminal and Readline key bindings for interrupting, suspending, editing and
  erasing command lines, plus vi-mode bindings. Covers which signal each Ctrl combination
  sends and when a key is handled by the terminal versus the shell.
tags:
  - terminal
  - shell
  - bash
  - zsh
  - readline
  - unix
  - linux
  - cli
  - cheatsheet
  - productivity
  - keyboard-shortcuts
  - job-control
  - signals
categories: linux
type: cheatsheet
status: evergreen
confidence: high
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2027-03-27
language: en
audience: linux-desktop
scope: readline and terminal emulator key handling
platform:
  - Linux
  - macOS
  - any POSIX shell
keywords:
  - SIGINT
  - SIGTSTP
  - SIGQUIT
  - SIGTSTP
  - EOF
  - Ctrl-C
  - Ctrl-Z
  - Ctrl-backslash
  - Ctrl-D
  - Ctrl-U
  - Ctrl-K
  - Ctrl-W
  - Ctrl-O
  - Ctrl-V Ctrl-J
  - Ctrl-M
  - Ctrl-X Ctrl-E
  - vi mode
  - insert mode
  - literal newline
  - fg
  - bg
  - job control
  - tty
sources:
  - "[GNU Readline manual](https://www.gnu.org/software/bash/manual/html_node/Readline-Builtins.html)"
  - "[Bash reference manual](https://www.gnu.org/software/bash/manual/bash.html)"
related:
  - "[[flatpak-apps]]"
  - "[[Bash]]"
  - "[[Zsh]]"
  - "[[Linux Command Cheatsheet]]"
  - "[[Job Control]]"
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document terminal keybindings"
ai-review: pending
cssclasses:
  - cheatsheet
  - wide-table
---

# Terminal Keybindings

## Interrupt / Stop / Suspend

| Key | Action |
|-----|--------|
| **Ctrl + C** | Sends `SIGINT` — interrupts/stops the current command |
| **Ctrl + Z** | Sends `SIGTSTP` — suspends/pauses the current process (resume with `fg` or `bg`) |
| **Ctrl + \\** | Sends `SIGQUIT` — harder interrupt (may produce core dump) |

## New Line / Line Editing

| Key | Action |
|-----|--------|
| **Ctrl + V, Ctrl + J** | Inserts a literal newline without executing |
| **Ctrl + M** or **Enter** | Executes the command |
| **Alt + Enter** | Inserts a newline (in some terminals like GNOME Terminal, iTerm2) |
| **Shift + Enter** | Inserts a newline (in some terminals/IDEs) |
| **Ctrl + O** | Executes current command, then recalls next from history |
| **Ctrl + X, Ctrl + E** | Opens line in `$EDITOR`, executes on save/quit |

## Erase / Delete

| Key | Action |
|-----|--------|
| **Ctrl + D** | Sends `EOF` — exits shell or closes input |
| **Ctrl + U** | Erases from cursor to beginning of line |
| **Ctrl + K** | Erases from cursor to end of line |
| **Ctrl + W** | Deletes the word before the cursor |

## Vi Mode (if enabled with `set -o vi`)

| Key | Action |
|-----|--------|
| **Enter** (insert mode) | Moves to next line |
| **Esc** then **o** | Opens a new line below |
| **Esc** then **O** | Opens a new line above |

## Sources
- [GNU Readline manual](https://www.gnu.org/software/bash/manual/html_node/Readline-Builtins.html) — manual
- [Bash reference manual](https://www.gnu.org/software/bash/manual/bash.html) — manual

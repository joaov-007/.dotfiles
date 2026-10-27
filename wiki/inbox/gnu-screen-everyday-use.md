---
title: "GNU Screen for Everyday Use"
aliases:
  - Screen cheatsheet
  - screen keybindings
  - terminal multiplexer screen
description: >-
  Practical GNU Screen workflow for Arch: session lifecycle, keybindings, copy mode,
  command-line mode, a sane .screenrc, and recipes for SSH, serial consoles and long jobs.
tags:
  - terminal
  - multiplexer
  - screen
  - gnu-screen
  - cli
  - ssh
  - cheatsheet
  - productivity
  - linux
type: cheatsheet
status: draft
created: 2026-10-27
updated: 2026-10-27
review_after: 2027-01-27
language: en
audience: linux-desktop
scope: GNU Screen 5.x on Arch Linux
platform:
  - Linux
  - Arch Linux
keywords:
  - screen -r
  - screen -dRR
  - screen -x
  - C-a
  - hardstatus
  - copy mode
  - scrollback
  - split
  - detach
  - serial console
sources:
  - "[GNU Screen manual](https://www.gnu.org/software/screen/manual/screen.html)"
  - "[Arch Wiki: GNU Screen](https://wiki.archlinux.org/title/GNU_Screen)"
related:
  - "[[Terminal Keybindings]]"
  - "[[SSH]]"
ai-gen: true
ai-model: "deepseek-v4.1-flash-free"
ai-provider: "opencode"
ai-prompt: "User request: teaching page for everyday screen usage with keybindings and command-line keys"
cssclasses: []
---

# GNU Screen for Everyday Use

Screen keeps a shell alive when your terminal dies. Close the laptop, drop the SSH link, kill the
terminal emulator — reattach and everything is where you left it, including the half-finished
`pacman -Syu`.

It is also the least intrusive multiplexer: installed on nearly every server, no plugin ecosystem,
no config language to learn. This page is the everyday subset plus the corners worth knowing.

```bash
sudo pacman -S screen     # already installed on most boxes
screen --version          # 5.0.2 on Arch as of 2026
```

## Mental model

Screen has three layers, and only the first one is tricky:

| Layer | What it is | How you address it |
| --- | --- | --- |
| Session | One screen process, one socket, survives disconnects | `screen -S name`, `screen -ls`, `screen -r name` |
| Window | A shell or process, full screen, switchable | <kbd>C-a n</kbd>, <kbd>C-a 0</kbd>…<kbd>9</kbd>, <kbd>C-a "</kbd> |
| Region | A split of the current window | <kbd>C-a S</kbd>, <kbd>C-a &#124;</kbd>, <kbd>C-a Tab</kbd> |

Everything is driven by a **prefix key**, <kbd>C-a</kbd> (Ctrl+A). Press it, release, then the
command key. Nothing else on the keyboard is intercepted, so <kbd>C-c</kbd>, <kbd>C-z</kbd>,
<kbd>C-r</kbd>, <kbd>C-d</kbd> and <kbd>C-l</kbd> behave normally inside your shells.

Two escape hatches worth memorising on day one:

- <kbd>C-a a</kbd> — send a literal <kbd>C-a</kbd> to the program (needed in Emacs and some REPLs).
- <kbd>C-a ?</kbd> — built-in keybinding list, always matches your installed version.

## Session commands

```bash
screen -S work                 # new named session
screen -ls                     # list sockets (attached / detached / dead)
screen -r work                 # reattach
screen -d work                 # detach it from wherever it is attached
screen -dr work                # detach elsewhere, attach here (the polite steal)
screen -dRR work               # attach if it exists, create if not, steal if needed
screen -x work                 # attach without detaching the other display (shared view)
screen -dmS build ./build.sh   # start detached, run a command, walk away
screen -S work -X quit         # terminate the whole session
screen -wipe                   # clean dead sockets after a crash or reboot
```

`screen -dRR` (or `-d -RR`) is the only invocation you really need in muscle memory: it does the
right thing whether or not a session already exists.

`screen -x` is a shared, read/write view for the same user. Cross-user attach needs
`multiuser on`, `acladd`, and suitable socket permissions; Arch ships screen without setuid, so
treat <kbd>C-a x</kbd>-style sharing as a trick for your own second terminal.

## Keybindings

Prefix is <kbd>C-a</kbd> unless you remap it. <kbd>C-a ?</kbd> prints this list on your machine.

### Windows and navigation

| Keys | Action |
| --- | --- |
| <kbd>C-a c</kbd> | New window with a shell |
| <kbd>C-a "</kbd> | Window list, pick with arrows and Enter |
| <kbd>C-a '</kbd> | Prompt for window number or title |
| <kbd>C-a w</kbd> | Window list in the message line |
| <kbd>C-a n</kbd> / <kbd>C-a p</kbd> | Next / previous window |
| <kbd>C-a Space</kbd> | Next window (cycles) |
| <kbd>C-a 0</kbd> … <kbd>C-a 9</kbd> | Jump to window by number |
| <kbd>C-a C-a</kbd> | Toggle to the previous window |
| <kbd>C-a A</kbd> | Rename current window |
| <kbd>C-a N</kbd> | Show number and title |
| <kbd>C-a k</kbd> | Kill current window (asks y/n) |
| <kbd>C-a K</kbd> | Kill without asking (Arch's `/etc/screenrc`) |
| <kbd>C-a \</kbd> | Kill all windows and quit immediately |

### Splits and regions

| Keys | Action |
| --- | --- |
| <kbd>C-a S</kbd> | Horizontal split (stacked) |
| <kbd>C-a &#124;</kbd> | Vertical split (side by side) |
| <kbd>C-a Tab</kbd> | Move focus to the next region |
| <kbd>C-a Q</kbd> | Close all other regions (keep current) |
| <kbd>C-a X</kbd> | Close current region, keep the window alive |
| <kbd>C-a F</kbd> | Resize current window to fit the region |
| <kbd>C-a :resize +5</kbd> | Grow region by 5 rows or columns |
| <kbd>C-a :resize max</kbd> | Give the region all available space |
| <kbd>C-a :layout new dev</kbd> | Create a new named layout |
| <kbd>C-a :layout select dev</kbd> | Switch to a saved layout |

Splits are per-session, not per-window. Layouts autosave by default, so a split arrangement comes
back after you detach and reattach; `layout dump` writes the split commands to a file if you want
them in `~/.screenrc`. If a full-screen app looks truncated after resizing the terminal or
reattaching, <kbd>C-a F</kbd> fixes it.

### Copy mode and scrollback

<kbd>C-a [</kbd> enters copy mode. It is a vi-like pager over the window's scrollback, not your
terminal emulator's scrollback.

| Keys | Action |
| --- | --- |
| <kbd>C-a [</kbd> / <kbd>C-a Esc</kbd> | Enter copy/scrollback mode |
| <kbd>j</kbd> <kbd>k</kbd> / arrows, <kbd>C-d</kbd> <kbd>C-u</kbd>, <kbd>C-b</kbd> <kbd>C-f</kbd> | Move, half-page, full page |
| <kbd>g</kbd> / <kbd>G</kbd> | Top / bottom of buffer |
| <kbd>/</kbd> then pattern, <kbd>n</kbd> / <kbd>N</kbd> | Search forward, next, previous |
| <kbd>?</kbd> then pattern | Search backward |
| <kbd>C-a s</kbd> / <kbd>C-r</kbd> | Incremental search forward / backward |
| <kbd>Space</kbd> / <kbd>Enter</kbd> | Set start / end mark |
| <kbd>y</kbd> / <kbd>Y</kbd> | Mark one whole line |
| <kbd>W</kbd> | Mark exactly one word |
| <kbd>c</kbd> / <kbd>C</kbd> | Set left / right margin (rectangular selection) |
| <kbd>J</kbd> | Cycle join mode: newline, glue, space, comma |
| <kbd>Enter</kbd> or <kbd>Space</kbd> on last mark | Copy to the paste buffer and exit |
| <kbd>C-a ]</kbd> | Paste buffer into the current window's stdin |
| <kbd>C-a ></kbd> | Write buffer to the exchange file |
| <kbd>C-a <</kbd> | Read exchange file into the buffer |
| <kbd>C-a =</kbd> | Delete the exchange file |

Copying to the desktop clipboard is the one thing screen does not do for you. Finish with
<kbd>C-a ></kbd>, then:

```bash
wl-copy < /tmp/screen-exchange     # Wayland
xclip -selection clipboard < /tmp/screen-exchange   # X11
```

The default exchange file is `/tmp/screen-exchange`, deliberately shared between users. For
anything private, pass a path: <kbd>C-a :writebuf ~/.cache/clip</kbd>, then copy from there.

### Session control and utilities

| Keys | Action |
| --- | --- |
| <kbd>C-a d</kbd> | Detach, leave everything running |
| <kbd>C-a D D</kbd> | Detach and log out |
| <kbd>C-a z</kbd> | Suspend screen itself; `fg` in the parent shell to resume |
| <kbd>C-a x</kbd> | Lock the terminal with your account password (PAM) |
| <kbd>C-a H</kbd> | Start/stop logging the window to `screenlog.n` |
| <kbd>C-a h</kbd> | Hardcopy of the current window to `hardcopy.n` |
| <kbd>C-a M</kbd> | Toggle activity monitoring for the window (flag in status line) |
| <kbd>C-a _</kbd> | Toggle silence monitoring (flag when nothing is printed) |
| <kbd>C-a i</kbd> | Window info |
| <kbd>C-a *</kbd> | List attached displays |
| <kbd>C-a :</kbd> | Command-line mode |
| <kbd>C-a ?</kbd> | Help |
| <kbd>C-a v</kbd> | Version |

## Shell command-line keys inside screen

Only the prefix is special. These keep their Readline meaning in every window:

| Keys | Action |
| --- | --- |
| <kbd>C-c</kbd> | Interrupt the foreground process (SIGINT) |
| <kbd>C-z</kbd> | Suspend it (SIGTSTP), then `bg` or `fg`; <kbd>C-a z</kbd> suspends screen instead |
| <kbd>C-d</kbd> | EOF / exit shell |
| <kbd>C-r</kbd> | Reverse history search |
| <kbd>C-l</kbd> | Clear the screen |
| <kbd>C-w</kbd> / <kbd>C-u</kbd> / <kbd>C-k</kbd> / <kbd>C-y</kbd> | Kill word / line before cursor / to end / yank |
| <kbd>C-a a</kbd> | Insert a literal <kbd>C-a</kbd> into the line |

If you live in Emacs or use <kbd>C-a</kbd> constantly at the prompt, remap the prefix instead:
`escape ^Bb` in `~/.screenrc`, or `screen -e^Bb` for one run. Then <kbd>C-b</kbd> is the prefix and
<kbd>C-a</kbd> stays Readline's beginning-of-line.

## Command-line mode (<kbd>C-a :</kbd>)

This is where screen stops feeling limited. Type a command, press Enter. Everything below also works
from a shell as `screen -S name -X <command>`, which is how you script a running session.

| Command | Effect |
| --- | --- |
| `screen -t logs tail -f /var/log/pacman.log` | New named window running a command |
| `title build` | Rename the current window |
| `number 3` | Move the current window to slot 3 |
| `split` / `split -v` | Horizontal / vertical split |
| `focus next` | Move focus between regions |
| `remove` / `only` | Close the region / close all others |
| `resize +5` / `resize max` | Resize the current region |
| `layout new work` / `layout select work` | Create / switch layouts |
| `layout dump ~/.screenrc` | Append the split commands to a file |
| `log on` / `logfile /tmp/install.log` | Logging controls |
| `stuff "make\n"` | Type text into the current window |
| `hardstatus alwayslastline` | Turn the status line on |
| `caption always "%n %t"` | Per-region caption line |
| `multiuser on` / `acladd alice` | Allow another account to attach |
| `source ~/.screenrc` | Reload config (new bindings apply immediately) |
| `quit` | Kill the session |

Shell-side equivalents, useful in scripts and tabs:

```bash
screen -S work -X screen -t logs tail -f ~/build.log   # new window in a running session
screen -S work -p 2 -X title inspect                   # rename window 2
screen -S work -X stuff $'make -j"$(nproc)"\n'          # send keystrokes
screen -S work -X logfile /tmp/deploy.log
screen -S work -X log on
screen -S work -Q number                               # query: current window number
screen -S work -p 2 -Q title                           # query: title of window 2
```

`stuff` sends literal characters; use `$'...\n'` so the shell expands the newline and the command
actually executes. Commands that change "the current window" (`title`, `log`, `stuff`) follow the
session's last selected window unless you pin it with `-p N`.

## A sane `.screenrc`

Arch's `/etc/screenrc` is a museum piece: visual bell with a "Wuff" message, no scrollback tuning,
no persistent status line. A short `~/.screenrc` fixes the modern annoyances without turning into a
tmux clone.

```screenrc
# ~/.screenrc
startup_message off
vbell off
defscrollback 50000          # copy-mode history, per window
defutf8 on
altscreen on                 # vim/less restore the screen on exit
truecolor on                 # screen 5.x: 24-bit colour
defmousetrack on             # click in copy mode and window list
shell -$SHELL                # new windows are login shells

hardstatus alwayslastline
hardstatus string "%{= 7;0}%-w%{= 0;3}%n %t%{-}%+w %=%{= 7;0}%H  %Y-%m-%d %c"
```

What the escapes do: `%{= 7;0}` sets white-on-black, `%-w`/`%+w` list windows before/after the
current one, `%{= 0;3}` highlights the current window black-on-yellow, `%n %t` is number and title,
`%=` right-aligns, `%H` is hostname, `%c` is the time in 24-hour format.

Validate a config without touching your running sessions:

```bash
screen -c ~/.screenrc -dmS rc-test bash
screen -ls
screen -S rc-test -X quit
```

Add per-window settings only when you need them. `caption always "%n %t"` costs a row in every
region but is genuinely useful in splits; skip it if you mostly run one window at a time.

## Everyday recipes

**Never lose a long job.** Start it detached, close the terminal, reattach later:

```bash
screen -dmS upgrade sudo pacman -Syu
screen -r upgrade          # reattach to type the sudo password / watch progress
```

**Attach-or-create over SSH.** In `~/.ssh/config`:

```
Host box
    RequestTTY yes
    RemoteCommand screen -dRR
```

Then `ssh box` always lands in the session, creating it on first connect. No wrapper script, no
"screen not found" on hosts that only have the system copy.

**Serial console / embedded boards.** Screen does this natively, no `picocom` needed:

```bash
sudo usermod -aG uucp "$USER"   # once; log out and back in
screen /dev/ttyUSB0 115200
# exit: C-a k, confirm — killing the last window ends the session
```

Arch puts `/dev/ttyUSB*` and `/dev/ttyACM*` in the `uucp` group, so group membership is the usual
missing piece when the device is "permission denied".

**A dev dashboard.** Named windows created detached, then attach once:

```bash
screen -dmS dev -t editor nvim
screen -S dev -X screen -t logs tail -f /tmp/dev.log
screen -S dev -X screen -t tests bash
screen -S dev -X screen -t shell bash
screen -r dev
# inside: C-a S, C-a Tab
```

Layouts autosave, so the split comes back after a detach. `C-a :layout dump ~/.screenrc` records the
split commands if you want to rebuild the dashboard from scratch next boot.

**Watch a build without staring at it.** <kbd>C-a M</kbd> on a build window flags activity in the
status line; <kbd>C-a _</kbd> flags silence. Good for long `cargo build` or `rsync` runs — check the
flag instead of polling.

**Keep evidence.** Log everything from the start:

```bash
screen -L -Logfile ~/logs/pacman-$(date +%F).log -S upgrade sudo pacman -Syu
```

**Shared debugging.** Same user, two terminals: `screen -x dev` in both. One drives, both see it.
<kbd>C-a d</kbd> detaches only your display.

## Gotchas

- **<kbd>C-a</kbd> collides with Readline/Emacs** (beginning of line). Either press <kbd>C-a a</kbd>
  before <kbd>C-a</kbd>, or remap the prefix with `escape ^Bb` / `screen -e^Bb`. Pick one and
  retrain; mixing them is worse than either.
- **Reattaching inside screen fails** with "Attaching from inside of screen?". Bypass the guard:
  `env -u STY screen -r other`.
- **Resize artifacts** after reattaching from a different terminal: <kbd>C-a F</kbd> on the
  affected window.
- **Dead sessions** after a crash or reboot: `screen -wipe`. The sockets live in `~/.screen`, which
  is mode 700 and should stay that way.
- **Colors look wrong** in a window: check `echo $TERM` — it should be `screen-256color` or
  `screen.xterm-256color`. Truecolor needs `truecolor on` *and* a terminal that supports it.
- **Scrollback is per window**, and only exists while the session lives. Reboot wipes it; use
  <kbd>C-a H</kbd> when you actually need a transcript.
- **Killing the last window kills the session** and drops every attached display. <kbd>C-a k</kbd>
  asks first; <kbd>C-a K</kbd> and <kbd>C-a \</kbd> do not. In splits, <kbd>C-a Q</kbd> and
  <kbd>C-a X</kbd> are usually what you want.
- **Log files grow forever.** <kbd>C-a H</kbd> and `-L` do not rotate. Stop logging or point
  `-Logfile` at a `tmpfiles.d`-managed path.
- **The lock is not a screen saver.** <kbd>C-a x</kbd> authenticates via PAM, but the processes
  behind it keep running and the session stays attachable by your user.
- **The exchange file is shared.** `/tmp/screen-exchange` is meant for passing text between users;
  use `writebuf ~/.cache/clip` for anything sensitive.
- **Don't nest by habit.** If you find yourself attaching screen inside screen, you wanted `-x` or
  a split. Nesting doubles the prefix handling for no benefit.

## Screen vs tmux

| | Screen | tmux |
| --- | --- | --- |
| Availability | Everywhere, by default | Often a package install |
| Config | Small, imperative `.screenrc` | Larger, declarative-ish `.tmux.conf` |
| Status line | Hardstatus strings | Formats and scripts |
| Splits | Layouts, autosave | Panes, layouts |
| Scripting | `screen -X`, `stuff`, `-Q` | `send-keys`, `run-shell`, control mode |
| Serial console | Built in | Needs `cu`/`picocom` |
| Clipboard/OSC52 | Manual (`writebuf` + `wl-copy`) | Plugins or built-in passthrough |
| Client-server | Implicit | Explicit, richer |

Use screen where it is already installed, on rescue shells, serial consoles, and machines you do
not administer. Use tmux when you want the larger ecosystem. Knowing screen is not optional if you
work on other people's servers.

## Quick card

```
C-a ?          help              C-a d        detach
C-a c          new window        C-a dRR      attach or create
C-a "          window list       C-a [        copy mode
C-a n / p      next / prev       C-a ]        paste
C-a 0-9        jump              C-a >        buffer to file
C-a A          rename            C-a S / |    split
C-a k          kill window       C-a Tab      focus region
C-a z          suspend           C-a F        fit window
C-a :          command mode      C-a a        literal C-a
```

If you only remember one thing: `screen -dRR name` to get back in, <kbd>C-a d</kbd> to get out.

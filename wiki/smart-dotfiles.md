---
title: Smart Dotfiles Manager
aliases: []
description: Layered dotfile installer with shared base + OS/host overlays — one config per program, no per-OS duplication.
tags:
  - dotfiles
  - linux
  - openbsd
  - freebsd
  - shell
  - installer
type: note
status: evergreen
created: 2026-11-14
updated: 2026-11-14
review_after: 2027-05-14
language: en
audience: maintainer
scope: home-dotfiles repo
platform:
  - linux
  - openbsd
  - freebsd
keywords:
  - dotfiles
  - stow
  - overlay
  - layered-install
  - env
related:
  - "[[Home]]"
  - "[[categories/development]]"
cssclasses: [reference]
ai-gen: true
ai-model: nemotron-3.5-super-vl-free
ai-provider: opencode
ai-prompt: "Write a wiki teaching how to build a smart stow-like dotfiles manager with OS/host overlays and useful tweaks"
ai-review: pending
---

# Smart Dotfiles Manager

> [!summary] One-paragraph answer
> Stop copying the same program config into every OS folder. Keep one copy under `config/shared/<pkg>`, and put only the files that actually differ under `config/env/<os>/<pkg>`. The installer walks layers from broad to specific — shared → env/common → env/$OS → env/$HOST — and the last layer wins. One command installs everything; a second command removes it cleanly.

## Context

Your current script stows one package per OS folder. To run the same program on Linux, OpenBSD and FreeBSD you end up copying `nvim/` into `common/`, `linux/`, `openbsd/` and `freebsd/`. Every tweak means editing four trees.

Stow isn't the problem — your **model** is. You're packaging per-OS instead of layering a shared base with per-OS deltas on top.

## Model

```
dotfiles/
├── config/
│   ├── shared/            # identical everywhere: git, nvim, starship, tmux
│   │   ├── git/
│   │   ├── nvim/
│   │   └── starship/
│   ├── env/
│   │   ├── common/        # shell aliases, editor vars shared on all OSes
│   │   ├── linux/         # only files that differ on linux
│   │   ├── openbsd/
│   │   ├── freebsd/
│   │   └── <hostname>/    # machine-specific tweaks
│   └── system/            # /etc files (root target, separate run)
├── bin/dot                # the smart installer (one script)
└── LINKS                  # optional manual override list
```

Rules:

- A program's **full** config lives once under `config/shared/<pkg>`.
- `env/<os>/<pkg>` contains **only** the files that differ on that OS.
- Overlays are applied **on top** of shared. If `shared/nvim/init.lua` and `env/linux/nvim/init.lua` both exist, the linux one wins.
- New OS? Add `env/<newos>/` with only the delta. No redoing shared configs.

## The installer

`bin/dot` is POSIX `sh` (~40 lines). It walks every package in every layer, symlinks each file into `$TARGET` (default `$HOME`), and backs up any real file already there to `<name>.dotfiles.bak` instead of clobbering it. Later layers replace earlier symlinks.

```sh
#!/bin/sh
# dot — layered dotfile installer.
# Layers (broad → specific): shared -> env/common -> env/$OS -> env/$HOST.
# Later layers override earlier ones.

set -eu

DOTFILES="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIG="$DOTFILES/config"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST="$(hostname | sed 's/\..*//' | tr '[:upper:]' '[:lower:]')"
TARGET="${DOTFILES_TARGET:-$HOME}"

LAYERS="shared env/common env/$OS env/$HOST"

command -v realpath >/dev/null 2>&1 || { echo "realpath required"; exit 1; }

install_pkg() {
    pkg="$1"
    srcs=""
    for layer in $LAYERS; do
        [ -d "$CONFIG/$layer/$pkg" ] && srcs="$srcs $CONFIG/$layer/$pkg"
    done
    [ -z "$srcs" ] && return 0

    echo "==> $pkg"
    for src in $srcs; do
        find "$src" -type f | while read -r file; do
            rel="${file#$src/}"
            tgt="$TARGET/$rel"
            abs="$(realpath "$file")"
            mkdir -p "$(dirname "$tgt")"

            if [ -e "$tgt" ] || [ -L "$tgt" ]; then
                if [ -L "$tgt" ] && [ "$(readlink "$tgt")" = "$abs" ]; then
                    continue
                fi
                if [ -L "$tgt" ]; then
                    rm -f "$tgt"
                elif [ -f "$tgt" ] || [ -d "$tgt" ]; then
                    mv "$tgt" "$tgt.dotfiles.bak"
                    echo "   backed up $tgt -> $tgt.dotfiles.bak"
                fi
            fi
            ln -s "$abs" "$tgt"
        done
    done
}

pkgs=""
for layer in $LAYERS; do
    [ -d "$CONFIG/$layer" ] && pkgs="$pkgs $(ls "$CONFIG/$layer" 2>/dev/null)"
done
pkgs="$(printf '%s' "$pkgs" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

for pkg in $pkgs; do
    install_pkg "$pkg"
done
```

Install:

```sh
chmod +x bin/dot
./bin/dot
```

Install to a different root (testing):

```sh
DOTFILES_TARGET=/tmp/test-home ./bin/dot
```

## Uninstall / restore

Run:

```sh
./bin/dot remove
```

It finds symlinks under `$TARGET` pointing into `$DOTFILES`, deletes them, and restores any `.dotfiles.bak` where present. Built into `bin/dot` — nothing to append.

## Declaring programs to install per OS

Dotfiles symlink config files; they don't install the programs themselves. Declare the packages each OS needs under `config/packages/`:

```
config/
├── packages/
│   ├── common      # installed everywhere
│   ├── linux       # linux-only packages
│   ├── openbsd
│   └── freebsd
└── shared/
    └── nvim/
```

One package name per line. Comments start with `#`. Example:

```
# config/packages/linux
sway
waybar
kitty
fzf
ripgrep
```

Run:

```sh
./bin/dot pkgs
```

The script:

1. Concatenates `config/packages/common` + `config/packages/$OS`, de-duplicated.
2. Skips anything already installed.
3. Installs the rest with your distro's package manager.

Supported package managers (auto-detected):

| Manager | OS | Install command |
|---|---|---|
| `pacman` | Arch Linux | `sudo pacman -S --needed --noconfirm` |
| `apt` | Debian/Ubuntu | `sudo apt-get install -y` |
| `pkg_add` | OpenBSD | `doas pkg_add` |
| `pkg` | FreeBSD | `sudo pkg install -y` |

If none is found, the script aborts with a clear message.

Edit `config/packages/<os>` whenever you add or remove a program — no script changes needed.

## Useful tweaks

### 1. Dry-run / preview

Before touching anything, print what would change:

```sh
DOTFILES_TARGET=/tmp/dry-run ./bin/dot
```

### 2. Skip packages by command availability

If a package only makes sense when a tool is installed, guard it inside `install_pkg`:

```sh
case "$pkg" in
    waybar) command -v waybar >/dev/null 2>&1 || return 0 ;;
esac
```

### 3. Exclude list (`LINKS`)

Create `LINKS` with one glob per line to skip:

```
.env
*.local
secrets/*
```

Then filter inside `install_pkg`:

```sh
if [ -f "$DOTFILES/LINKS" ]; then
    while read -r pat; do
        case "$rel" in
            $pat) continue 2 ;;
        esac
    done < "$DOTFILES/LINKS"
fi
```

### 4. Host-specific overrides

`config/env/my-laptop/.bashrc` applies only to that machine. The host layer runs last, so it wins over everything.

### 5. System-wide files (`/etc`)

Keep root-owned files under `config/system/` and run a second pass as root with `TARGET=/etc`:

```sh
sudo DOTFILES_TARGET=/etc ./bin/dot
```

Only do this for files you trust; review `config/system/` before running as root.

### 6. Keep using stow (optional)

If you prefer stow itself, keep the same folder layout (`shared/` + `env/<os>/`) and run:

```sh
stow -d config -t $HOME shared
stow -d config -t $HOME env/common
stow -d config -t $HOME env/linux
```

The order matters: later stow runs overwrite conflicting symlinks. `bin/dot` does this layering for you without stow's conflict errors.

### 7. Pin a layer order

If you want env/common to override shared (unusual, but possible), reorder `LAYERS`:

```sh
LAYERS="shared env/$OS env/common env/$HOST"
```

Last listed wins.

## Verification

After running `./bin/dot`:

```sh
# confirm a shared file is linked everywhere
readlink ~/.config/nvim/init.lua
# → /home/joaov/.dotfiles/config/shared/nvim/init.lua

# confirm a linux override won
readlink ~/.config/nvim/init.lua   # on linux shows env/linux/nvim/init.lua

# list all dot-managed symlinks
find ~ -type l -lname "$DOTFILES/*"

# nothing clobbered — backups exist only where a real file was replaced
find ~ -name '*.dotfiles.bak'
```

## Related

- [[Home]] — wiki entry point
- [[categories/development]] — where tooling notes live

## Sources

- Your existing `config/scripts/install.sh` (the per-OS stow script this replaces)
- GNU Stow — symlink farm manager; the original motivation for this layout
- `ln(1)`, `realpath(1)`, `find(1)` — primitives the installer uses

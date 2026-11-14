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
│   ├── shared/            # mirrors $HOME: .bashrc, .config/nvim/, .local/bin/
│   │   ├── .bashrc
│   │   ├── .config/
│   │   │   ├── git/
│   │   │   ├── nvim/
│   │   │   └── ...
│   │   └── .local/
│   │       └── bin/
│   ├── env/
│   │   ├── common/        # only files that differ from shared, all OSes
│   │   ├── linux/         # only files that differ on linux
│   │   ├── openbsd/
│   │   ├── freebsd/
│   │   └── <hostname>/    # machine-specific tweaks
│   ├── packages/          # programs to install per OS
│   │   ├── common
│   │   ├── linux
│   │   ├── openbsd
│   │   └── freebsd
│   └── system/            # /etc files (root target, separate run)
├── bin/dot                # the smart installer (one script)
└── LINKS                  # optional manual override list
```

Rules:

- `config/shared/` mirrors `$HOME`: `.bashrc` → `~/.bashrc`, `.config/nvim/init.lua` → `~/.config/nvim/init.lua`
- A program's **full** config lives once under `config/shared/`.
- `env/<os>/<pkg>` contains **only** the files that differ on that OS, using the same relative path as in shared.
- Overlays are applied **on top** of shared. If `shared/.config/nvim/init.lua` and `env/linux/.config/nvim/init.lua` both exist, the linux one wins.
- New OS? Add `env/<newos>/` with only the delta. No redoing shared configs.

## The installer

`bin/dot` walks every file in each layer (broad → specific) and symlinks it into `$TARGET`. Later layers replace earlier symlinks. Real files already in `$HOME` get backed up to `.dotfiles.bak` instead of being clobbered.

```sh
#!/bin/sh
# dot — layered dotfile installer + per-OS package declarations.
# Layers (broad → specific): shared -> env/common -> env/$OS -> env/$HOST.
# Later layers override earlier ones.

set -eu

DOTFILES="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CONFIG="$DOTFILES/config"
PKGS="$CONFIG/packages"
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
HOST="$(hostname | sed 's/\..*//' | tr '[:upper:]' '[:lower:]')"
TARGET="${DOTFILES_TARGET:-$HOME}"

LAYERS="shared env/common env/$OS env/$HOST"

command -v realpath >/dev/null 2>&1 || { echo "realpath required"; exit 1; }

dotfiles() {
    for layer in $LAYERS; do
        [ -d "$CONFIG/$layer" ] || continue
        echo "==> layer: $layer"
        find "$CONFIG/$layer" -type f | while read -r file; do
            rel="${file#$CONFIG/$layer/}"
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

remove_dotfiles() {
    find "$TARGET" -type l 2>/dev/null | while read -r link; do
        target="$(readlink "$link")"
        case "$target" in
            "$DOTFILES"/*)
                rm -f "$link"
                if [ -e "$link.dotfiles.bak" ]; then
                    mv "$link.dotfiles.bak" "$link"
                    echo "restored $link"
                else
                    echo "removed $link"
                fi
                ;;
        esac
    done
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
    case "$PKG_MGR" in
        pacman)  pacman -Q "$1" >/dev/null 2>&1 ;;
        apt)     dpkg -s "$1" >/dev/null 2>&1 ;;
        pkg_add) pkg_info -e "$1" >/dev/null 2>&1 ;;
        pkg)     pkg info -e "$1" >/dev/null 2>&1 ;;
        *)       return 1 ;;
    esac
}

detect_pkg_mgr() {
    if has_cmd pacman; then PKG_MGR=pacman; PKG_INSTALL="sudo pacman -S --needed --noconfirm"
    elif has_cmd apt; then PKG_MGR=apt; PKG_INSTALL="sudo apt-get install -y"
    elif has_cmd pkg_add; then PKG_MGR=pkg_add; PKG_INSTALL="doas pkg_add"
    elif has_cmd pkg; then PKG_MGR=pkg; PKG_INSTALL="sudo pkg install -y"
    else
        echo "no supported package manager found (pacman, apt, pkg_add, pkg)"
        return 1
    fi
}

install_packages() {
    detect_pkg_mgr || return 1

    want=""
    [ -f "$PKGS/common" ] && want="$want $(cat "$PKGS/common")"
    [ -f "$PKGS/$OS" ] && want="$want $(cat "$PKGS/$OS")"
    want="$(printf '%s' "$want" | tr ' ' '\n' | sort -u | tr '\n' ' ')"

    missing=""
    for p in $want; do
        if ! pkg_installed "$p"; then
            missing="$missing $p"
        fi
    done

    if [ -z "$missing" ]; then
        echo "all packages already installed"
        return 0
    fi

    echo "installing:$missing"
    # shellcheck disable=SC2086
    $PKG_INSTALL $missing
}

case "${1:-dotfiles}" in
    dotfiles|install) dotfiles ;;
    pkgs|packages)    install_packages ;;
    remove|uninstall) remove_dotfiles ;;
    *) echo "usage: $0 {dotfiles|pkgs|remove}"; exit 1 ;;
esac
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

### 2. Exclude list (`LINKS`)

Create `LINKS` with one glob per line to skip:

```
.env
*.local
secrets/*
```

Then filter inside `dotfiles()`:

```sh
if [ -f "$DOTFILES/LINKS" ]; then
    while read -r pat; do
        case "$rel" in
            $pat) continue ;;
        esac
    done < "$DOTFILES/LINKS"
fi
```

Place the check right after `rel="${file#$CONFIG/$layer/}"` so matching files are skipped.

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
readlink ~/.bashrc
# → /home/joaov/.dotfiles/config/shared/.bashrc

readlink ~/.config/nvim/init.lua
# → /home/joaov/.dotfiles/config/shared/.config/nvim/init.lua

# confirm a linux override won
readlink ~/.bashrc   # on linux shows env/linux/.bashrc

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

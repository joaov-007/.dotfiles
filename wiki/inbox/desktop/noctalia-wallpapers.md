---
title: "Noctalia wallpapers by theme"
aliases:
  - Noctalia wallpaper themes
  - Theme-aware wallpapers
  - Wallpaper directory layout
description: >-
  How Noctalia v5 organises wallpapers: light/dark and per-monitor directories, theme
  subfolders in the picker, favorites that pin a palette, and generating the palette from
  the current wallpaper. Includes the config precedence rule that trips people up.
tags:
  - linux
  - noctalia
  - wayland
  - niri
  - theming
  - desktop
  - wallpaper
categories: desktop
type: guide
status: draft
created: 2026-10-11
updated: 2026-10-11
last_reviewed: 2026-10-11
review_after: 2027-01-11
language: en
audience: desktop user
scope: organising wallpaper collections and theme-aware wallpaper switching in Noctalia v5
platform:
  - Arch Linux
  - Wayland
  - niri
keywords:
  - Noctalia
  - wallpaper.directory
  - directory_light
  - directory_dark
  - per_monitor_directories
  - wallpaper.automation
  - wallpaper.favorite
  - color-scheme-set
  - m3-tonal-spot
  - Material You
  - settings.toml
  - config.toml
sources:
  - "[Wallpaper & Backdrop — Noctalia docs](https://docs.noctalia.dev/noctalia/desktop/wallpaper/)"
  - "[How configuration works — Noctalia docs](https://docs.noctalia.dev/noctalia/configuration/)"
  - "[Is there any quick way to switch wallpaper folders — noctalia issue #2341](https://github.com/noctalia-dev/noctalia/issues/2341)"
related:
  - "[[vesktop-noctalia-theme]]"
  - "[[qemu-automated-testing]]"
  - "[[niri-screencasting]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Asked how to make and organise wallpapers by theme for the Noctalia shell, and whether it groups by theme or only light/dark"
ai-review: pending
---

# Noctalia wallpapers by theme

> [!summary] Noctalia has folders, not themes
> Noctalia's only built-in wallpaper split is **Light vs Dark** (plus optional per-monitor
> folders). Anything richer — anime, minimal, nature — is you using subfolders in the
> picker, or swapping the `directory` value. Separately, you can make the *palette* follow
> the wallpaper with `color-scheme-set wallpaper`, which is the closest thing to "each
> wallpaper is its own theme."

## Context

You have a pile of wallpapers and want the desktop to reflect a mood, not just show one
image. Two questions hide inside that:

1. **Organising** — where do files go, and what does the picker actually show?
2. **Theming** — does the shell's colour palette change when the wallpaper changes?

Both come down to the same fact: Noctalia groups wallpapers by *folder* only. There is no
tag, no metadata, no named theme list. You build the taxonomy on the filesystem.

## Details

### 1. The axes Noctalia actually understands

| Axis | Key | Behaviour |
|---|---|---|
| Light / Dark | `wallpaper.directory_light`, `wallpaper.directory_dark` | Used when theme mode is Light or Dark. `Auto` and any missing path fall back to `directory`. This is the "white / black wallpapers" split, and it is the only built-in one. |
| Per monitor | `wallpaper.per_monitor_directories` + `[wallpaper.monitor.<name>]` | Different folder per output, e.g. a vertical monitor. Off by default. |
| Everything else | `wallpaper.directory` + subfolders | Plain folders the picker can browse into. No names, no grouping. |
| The palette | `[theme] source` + `wallpaper_scheme` | Whether the shell recolours *from* the wallpaper. Independent of the folder layout. |

Automation does **not** cycle per theme. With `recursive = true` it walks every subfolder
and treats them all as one flat pool.

### 2. A layout that works

```
~/Pictures/wallpapers/
├── light/            # -> directory_light
├── dark/             # -> directory_dark
└── themes/           # browsed by hand in the picker
    ├── anime/
    ├── minimal/
    ├── nature/
    └── space/
```

Light/dark only earn their keep if you actually flip theme mode. If you always run dark,
collapse them and put everything under `themes/`.

### 3. Config

Put the declarative values in `~/.config/noctalia/config.toml`:

```toml
[wallpaper]
enabled = true
fill_mode = "crop"
fill_color = "surface"            # palette role, so letterbox areas follow the theme

directory       = "/home/joaov/Pictures/wallpapers/themes"
directory_light = "/home/joaov/Pictures/wallpapers/light"
directory_dark  = "/home/joaov/Pictures/wallpapers/dark"

[wallpaper.automation]
enabled = true
interval_seconds = 1800
order = "random"                  # random | alphabetical
recursive = true                  # include the theme subfolders
```

Precedence: built-in defaults → `~/.config/noctalia/*.toml` → `~/.local/state/noctalia/settings.toml`.
**The GUI-managed `settings.toml` loads last and wins.** If a declarative `directory` seems
ignored, that key is almost certainly also set in `settings.toml` from a previous UI change.

### 4. Make the palette follow the wallpaper

By default the palette is fixed (a builtin, community, or custom scheme). To derive it from
whatever wallpaper is showing:

```bash
noctalia msg color-scheme-set wallpaper m3-content   # or m3-tonal-spot, vibrant, ...
noctalia msg color-scheme-get                        # confirm: "wallpaper m3-content"
```

`noctalia theme` also generates a palette from any image, which is a dry run before
committing:

```bash
noctalia theme ~/Pictures/wallpapers/themes/space/sol-moon.png --scheme m3-content --dark
```

This is the real answer to "wallpapers by theme": with `source = wallpaper`, switching the
image *is* switching the theme, and every app on the template chain retints with it.

### 5. Favorites pin a look

A starred wallpaper can store its own theme preset, so re-applying it restores the exact
look. Declare it in config:

```toml
[[wallpaper.favorite]]
path = "/home/joaov/Pictures/wallpapers/themes/anime/girl-gun.png"
theme_mode = "dark"
palette_source = "wallpaper"
wallpaper_scheme = "m3-content"
```

Favorites appear pinned at the top of the browse grid. Starring a wallpaper in the UI while
it is applied also captures the active theme fields.

### 6. Switch theme folders at runtime

There is no built-in folder switcher; a theme change means repoint `directory`, reload, then
pick. The relevant IPC is `noctalia msg`:

```bash
noctalia msg config-reload                 # after editing the directory
noctalia msg wallpaper-random              # pick from the new folder
noctalia msg wallpaper-next                # cycle forward
noctalia msg wallpaper-previous
noctalia msg wallpaper-set eDP-1 /path/to/img.png
noctalia msg wallpaper-get eDP-1           # print the effective path
noctalia msg theme-mode-toggle             # light <-> dark (drives directory_light/dark)
```

A helper to flip between theme folders and rebind it to a key:

```bash
#!/usr/bin/env bash
set -euo pipefail
theme="${1:?usage: wallpaper-theme <theme-folder>}"
base=/home/joaov/Pictures/wallpapers/themes
state=~/.local/state/noctalia/settings.toml
[[ -d "$base/$theme" ]] || { echo "no such theme: $theme" >&2; exit 1; }
sed -i "s#^directory = \"/home/joaov/Pictures/wallpapers/themes/.*\"#directory = \"$base/$theme\"#" "$state"
noctalia msg config-reload
noctalia msg wallpaper-random
```

It edits `settings.toml` (the winning layer) rather than `config.toml`, so it agrees with the
GUI. If you would rather keep it declarative, drop the `directory` key from `settings.toml`
once and edit `config.toml` instead — but the next UI browse-folder change will re-add it.

## Gotchas

> [!warning] `settings.toml` silently overrides your config
> Editing `wallpaper.directory` in `~/.config/noctalia/config.toml` and seeing no change means
> the key is also present in `~/.local/state/noctalia/settings.toml`. That file loads last.
> Check with `noctalia config export full | grep -A12 '^\[wallpaper\]'` — it shows the merged
> result, so it tells you the value that actually won.

> [!caution] `~` is not expanded for `wallpaper.directory`
> Use absolute paths. `directory = "~/Pictures/wallpapers"` is taken literally and points at
> a folder named `~`. (`~` *is* expanded inside `[include]`, which is a different code path.)

> [!caution] Automation is one pool, not one-per-theme
> `recursive = true` flattens every subfolder into a single rotation. Adding theme folders
> does not create per-theme cycles. To rotate within one theme, point `directory` at that
> theme folder.

> [!warning] Changing the folder does not re-apply the wallpaper
> After `config-reload`, the currently displayed image stays until the next pick. Follow with
> `wallpaper-random` or `wallpaper-next`, or re-apply an explicit path.

> [!tip] `fill_color` should be a role, not a hex
> `fill_color = "surface"` makes letterbox/fallback areas follow the active palette. A fixed
> hex is only right when you deliberately want a non-theme fill.

## Verification

```bash
# no ERROR lines; warnings are advisory
noctalia config validate

# the value that actually won the merge
noctalia config export full | grep -A12 '^\[wallpaper\]'

# "wallpaper m3-content" once the palette follows the image
noctalia msg color-scheme-get

# the path currently applied to a monitor
noctalia msg wallpaper-get eDP-1
```

Expected: `wallpaper.directory` matches the folder you set, `directory_light`/`directory_dark`
resolve when you toggle theme mode, and each new wallpaper recolours the shell once
`color-scheme-get` reports a `wallpaper` source.

## Related

- [[vesktop-noctalia-theme]] — the same palette chain applied to a specific app template.
- [[qemu-automated-testing]] — Noctalia installed and configured inside the test VMs.
- [[niri-screencasting]] — the compositor Noctalia runs on here.

## Sources

- [Wallpaper & Backdrop — Noctalia docs](https://docs.noctalia.dev/noctalia/desktop/wallpaper/) — the `[wallpaper]` keys, fill modes, favorites, per-monitor directories, automation.
- [How configuration works — Noctalia docs](https://docs.noctalia.dev/noctalia/configuration/) — the two config layers and the "settings.toml wins" precedence rule.
- [noctalia issue #2341](https://github.com/noctalia-dev/noctalia/issues/2341) — confirms there is no built-in folder switcher; users script the directory swap plus `config-reload`.
- `noctalia msg --help` and `noctalia theme --help` on this machine — the exact IPC command names and palette-generation flags.

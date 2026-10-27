---
title: "Vesktop + Noctalia — Discord that matches the shell"
description: "Wiring the discord community template so Vesktop retints with the live Noctalia palette."
tags:
  - linux
  - noctalia
  - theming
  - css
  - vesktop
  - discord
  - flatpak
categories: desktop
type: guide
status: draft
created: 2026-09-26
updated: 2026-10-12
related:
  - arch-setup
  - noctalia-wallpapers
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document Vesktop theming with Noctalia"
ai-review: pending
language: en
audience: user
scope: theming Vesktop to match Noctalia
keywords:
  - vesktop
  - noctalia
  - theme
  - css
  - discord
platform:
  - Linux
  - niri
  - Flatpak
cssclasses:
  - nota-longa
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Vesktop + Noctalia — Discord that matches the shell

Noctalia already ships everything needed. There is no script to write: the
`discord` community template has a **Vesktop** target, so the CSS is regenerated
from the live palette every time the theme changes.

Vesktop is a native Linux client (Vencord-based). It is installed here via
Flatpak, which matches the flatpak-first approach in `arch-setup.md`.

Nothing on this page has been applied. It is documentation only.

---

## How it fits together

Noctalia keeps every app on one palette. On this machine that chain is:

```
Noctalia palette  (community: "Tokyo Night Storm")
      |
      +--> alacritty template  ->  ~/.config/alacritty/themes/noctalia.toml
      |                             (the named-colour export everything else reads)
      +--> builtin/community templates -> gtk3, gtk4, qt, btop, cava, niri, bat, fzf, ...
      +--> user template + post_hook -> delta, starship, neovim
      +--> discord_midnight_vesktop_flatpak
                                ->  ~/.var/app/dev.vencord.Vesktop/config/vesktop/themes/
```

Switch palette at runtime with `Mod+Shift+d` and Discord retints with everything else.

---

## 1. Install Vesktop

```bash
sudo flatpak --system remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak install --system --noninteractive -y flathub dev.vencord.Vesktop
```

App id: `dev.vencord.Vesktop` — a native client, not the `com.discordapp.Discord`
flatpak, so it is themable and does not need Discord's own updater.

## 2. Turn on the template

Noctalia writes the theme file, but only for template ids listed in its config.
Add the flatpak Vesktop entry to `community_ids` in `~/.config/noctalia/config.toml`:

```toml
[theme.templates]
community_ids = [ "bat", "fzf", "fuzzel", "glow", "lazygit", "zellij", "discord_midnight_vesktop_flatpak" ]
```

The template writes to:

```
~/.var/app/dev.vencord.Vesktop/config/vesktop/themes/noctalia.theme.css
```

Note the `_flatpak` suffix on the id. The non-suffixed
`discord_midnight_vesktop` targets `~/.config/vesktop/` and is the wrong
destination for a flatpak install.

## 3. Enable it once in Vesktop

Noctalia only generates the file. Vencord still needs permission to apply it:

1. Launch Vesktop.
2. `Settings` -> `Vencord` -> `Themes`.
3. Enable `noctalia.theme`.

That toggle is the only manual step. Afterwards the file is maintained for you.

## 4. Verify

```bash
THEME=~/.var/app/dev.vencord.Vesktop/config/vesktop/themes/noctalia.theme.css

# Noctalia should have rendered the file
ls -l "$(dirname "$THEME")"

# colours should match the shell's palette
diff <(grep -oE '#[0-9a-fA-F]{6}' ~/.config/alacritty/themes/noctalia.toml | sort -u) \
     <(grep -oE '#[0-9a-fA-F]{6}' "$THEME" | sort -u)
```

A palette that overlaps the Alacritty export is the expected result.

---

## Template variants

All three Vesktop targets live under `[templates.discord_*]` in
`~/.local/state/noctalia/community-templates/discord/template.toml`:

| Template id | Writes to | Look |
|---|---|---|
| `discord_midnight_vesktop_flatpak` | `.../themes/noctalia.theme.css` | closest to Noctalia's own surfaces |
| `discord_material_vesktop_flatpak` | `.../themes/noctalia-material.theme.css` | Material, rounder, tonal |
| `discord_system24_vesktop_flatpak` | `.../themes/discord-system24.css` | Fluent-style, Windows-like |

Swap the id in `community_ids` and re-run. The catalogue also has native (non-flatpak)
variants for `vesktop`, `webcord`, `equicord`, `lightcord`, `dorion` and
`betterdiscord` — those write to `$XDG_CONFIG_HOME/<app>/themes/` and only apply
to non-flatpak installs.

---

## Troubleshooting

**Theme file never appears.** The CSS assets are fetched from
`https://api.noctalia.dev/templates`, not shipped in the package. The Noctalia
log currently shows those requests failing:

```
[WRN] [http] download failed url=https://api.noctalia.dev/templates
       curl=28 http=0 error=Resolving timed out after 10000 milliseconds
```

Only `template.toml` is cached locally right now, so a first render needs DNS
for `api.noctalia.dev` to resolve. Verify with:

```bash
curl -sI https://api.noctalia.dev/templates | head -1
getent hosts api.noctalia.dev
```

Until that resolves, the template writes nothing. Nothing else in the palette
chain is affected — alacritty, gtk, qt, btop, delta, starship and neovim are
all unaffected.

**Theme is listed but does nothing.** Confirm theme support is on in Vencord,
and that you are looking at the flatpak path
`~/.var/app/dev.vencord.Vesktop/config/vesktop/themes/` and not a leftover
`~/.config/vesktop/` from a previous non-flatpak install.

**Still the stock Discord look.** Mod+Shift+d regenerates the file, but Vencord
reads it at startup — restart Vesktop to pick up a palette change.

**Sandbox blocks a file.** Vesktop's flatpak is confined. If the theme applies
partially, give it access to the paths it needs (Flatseal, or
`--filesystem=` overrides) rather than loosening the whole sandbox.

---

## Rollback

```bash
# drop the template
#   remove "discord_midnight_vesktop_flatpak" from community_ids, restart Noctalia

# remove the generated file
rm ~/.var/app/dev.vencord.Vesktop/config/vesktop/themes/noctalia.theme.css

# remove the client (with its config)
flatpak uninstall --system --noninteractive -y dev.vencord.Vesktop
rm -rf ~/.var/app/dev.vencord.Vesktop
```

Do not `paru -R vesktop-bin` — that is the AUR build and is not what is
documented here.

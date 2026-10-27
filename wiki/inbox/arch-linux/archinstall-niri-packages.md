---
title: "Archinstall Niri Profile — Default Packages"
description: "Reference listing of default and conditional packages in the archinstall Niri desktop profile"
tags:
  - arch
  - niri
  - packages
  - reference
  - wayland
  - linux
categories: arch-linux
categories: arch-linux
type: reference-list
status: draft
created: 2026-09-28
updated: 2026-10-12
related:
  - arch-setup
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document archinstall Niri profile packages"
ai-review: pending
language: en
audience: sysadmin
scope: default packages of the archinstall Niri profile
keywords:
  - archinstall
  - niri
  - packages
  - Wayland
platform:
  - Arch Linux
  - niri
  - Wayland
cssclasses:
  - reference
  - wide-table
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Archinstall Niri Profile — Default Packages

Source: `archinstall/default_profiles/desktops/niri.py`

## Base Packages (always installed)

- niri
- alacritty
- fuzzel
- mako
- xorg-xwayland
- waybar
- swaybg
- swayidle
- swaylock
- xdg-desktop-portal-gnome

## Conditional Packages (seat access — user choice)

| Option | Package | Service |
|---|---|---|
| seatd | seatd | seatd (enabled) |
| systemd-logind | polkit | (none — dbus activated) |

## Greeter

- LightDM (default)

## Notes

- Profile type: WindowMgr
- Display server: Wayland
- Supports graphics drivers: yes

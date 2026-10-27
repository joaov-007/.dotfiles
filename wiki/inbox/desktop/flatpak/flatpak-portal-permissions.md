---
title: "Flatpak Portal Permissions — Microphone & Remote Desktop"
description: "Debug note for Speed of Sound (speech-to-text) failing to create a RemoteDesktop portal session on niri."
tags:
  - linux
  - flatpak
  - permissions
  - microphone
  - remote-desktop
  - speedofsound
  - debug
  - niri
type: guide
status: draft
created: 2026-09-27
updated: 2026-10-12
related:
  - flatpak-apps
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document Flatpak portal permissions debugging"
ai-review: pending
language: en
audience: user
scope: "Flatpak portal permissions (microphone, remote desktop)"
keywords:
  - flatpak
  - portal
  - permissions
  - microphone
  - remote-desktop
platform:
  - Linux
  - Flatpak
cssclasses:
  - nota-longa
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Flatpak Portal Permissions — Microphone & Remote Desktop

## The app

**Speed of Sound** (`io.speedofsound.SpeedOfSound`) — a Flatpak speech-to-text
transcriber. It uses the **RemoteDesktop** portal to register global shortcuts
(push-to-talk), and GStreamer + PipeWire for microphone capture.

## The error

```
A backend call failed: No such interface "org.freedesktop.impl.portal.RemoteDesktop"
  on object at path /org/freedesktop/portal/desktop
```

Speed of Sound calls `CreateSession` on the RemoteDesktop portal, the portal
has no backend that implements it, and the session fails.

## Root cause

The installed portal backends are:

| Backend | RemoteDesktop? |
|---|---|
| `xdg-desktop-portal-gtk` (1.15.3) | No |
| `xdg-desktop-portal-gnome` (50.0) | No |

The niri portal config (`/usr/share/xdg-desktop-portal/niri-portals.conf`)
only maps three interfaces:

```ini
[preferred]
default=gnome;gtk;
org.freedesktop.impl.portal.Access=gtk;
org.freedesktop.impl.portal.Notification=gtk;
org.freedesktop.impl.portal.Secret=gnome-keyring;
```

No `RemoteDesktop` mapping — so even if a backend supported it, the config
would not route the call.

## What Speed of Sound needs

| Portal interface | Purpose | Status |
|---|---|---|
| `org.freedesktop.portal.RemoteDesktop` | Global shortcuts (push-to-talk) | **Missing** — no backend |
| `org.freedesktop.portal.GlobalShortcuts` | Alternative for global shortcuts | Available, but app uses RemoteDesktop |
| Microphone (PipeWire) | Audio capture for ASR | Working — GStreamer initialized OK |

## Resolution

**Applied fix:**

1. Installed `xdg-desktop-portal-kde` (6.7.5-1)
2. Added to `~/.config/xdg-desktop-portal/portals.conf`:
   ```ini
   org.freedesktop.impl.portal.RemoteDesktop=kde;
   org.freedesktop.impl.portal.GlobalShortcuts=gnome;
   ```
3. Restarted the portal: `systemctl --user restart xdg-desktop-portal.service`

**Result:** Both `RemoteDesktop` and `GlobalShortcuts` interfaces are now
exposed. Speed of Sound's `CreateSession` call succeeds.

**Why KDE?** Neither `xdg-desktop-portal-gtk` nor `xdg-desktop-portal-gnome`
implement RemoteDesktop. The KDE backend does. The `GlobalShortcuts` portal
works fine through the gnome backend, so only RemoteDesktop needs KDE.

**Trade-off:** `xdg-desktop-portal-kde` pulls ~50 MB of Qt/KF5 dependencies.
This is the only backend on the market that implements RemoteDesktop without
a full GNOME session.

## Debugging commands

```bash
# Confirm which portal backends are running
ps aux | grep xdg-desktop-portal | grep -v grep

# List all portal interfaces the running portal exposes
busctl --user introspect org.freedesktop.portal.Desktop \
  /org/freedesktop/portal/desktop | grep interface

# Watch portal calls in real-time
journalctl --user -f -u xdg-desktop-portal.service

# Check Flatpak overrides for the app
flatpak override --user --show io.speedofsound.SpeedOfSound

# Check PipeWire microphone sources
pactl list short sources
```

## Verification

After applying a fix:

1. Restart the portal: `systemctl --user restart xdg-desktop-portal.service`
2. Restart Speed of Sound
3. Check the journal — the `No such interface` error should be gone
4. The app should show "Global Shortcuts session created successfully"

## Related

- [[flatpak-apps]] — full app list with per-app permission notes

---
title: Screencasting
description: "Niri screencasting using portals, pipewire, OBS, and dynamic cast targets"
tags:
  - linux
  - arch
  - security
  - setup
categories: desktop
type: guide
status: draft
created: 2026-10-07
updated: 2026-10-12
related: []
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document Niri screencasting with portals and pipewire"
ai-review: pending
language: en
audience: user
scope: screen capture on the niri Wayland compositor
keywords:
  - niri
  - screencast
  - xdg-desktop-portal
  - wayland
  - recording
platform:
  - Linux
  - niri
  - Wayland
cssclasses:
  - nota-longa
last_reviewed: 2026-10-12
review_after: 2027-01-12
---
<!--
  This page was generated from the Niri wiki Screencasting page:
  https://github.com/niri-wm/niri/wiki/Screencasting
  AI-generated content - review before use.
-->

# Screencasting

[Jump to bottom](#wiki-pages-box)

github-actions\[bot\] edited this page Sep 12, 2026 · 10 revisions

### Overview

The primary screencasting interface that niri offers is through portals and pipewire. It is supported by [OBS](https://obsproject.com/), Firefox, Chromium, Electron, Telegram, and other apps. You can screencast both monitors and individual windows.

In order to use it, you need a working D-Bus session, pipewire, `xdg-desktop-portal-gnome`, and [running niri as a session](./Getting-Started) (i.e. through `niri-session` or from a display manager). On widely used distros this should all "just work".

Alternatively, you can use tools that rely on the `ext-image-copy-capture` protocol, or the older `wlr-screencopy`, both of which niri also supports.

There are several features in niri designed for screencasting. Let's take a look!

### Block out windows

You can block out specific windows from screencasts, replacing them with solid black rectangles. This can be useful for password managers or messenger windows, etc.

This is controlled through the `block-out-from` window rule, for example:

```
// Block out password managers from screencasts.
window-rule {
    match app-id=r#"^org\.keepassxc\.KeePassXC$"#
    match app-id=r#"^org\.gnome\.World\.Secrets$"#

    block-out-from "screencast"
}
```

You can similarly block out layer surfaces, using a layer rule:

```
// Block out mako notifications from screencasts.
layer-rule {
    match namespace="^notifications$"

    block-out-from "screencast"
}
```

Check [the corresponding wiki section](./Configuration:-Window-Rules#block-out-from) for more details and examples.

### Dynamic screencast target

Since: 25.05

Niri provides a special screencast stream that you can change dynamically. It shows up as "niri Dynamic Cast Target" in the screencast window dialog.

Choose it, then use the following binds to change what it shows. The stream won't start until you make your first target selection.

- `set-dynamic-cast-window` to cast the focused window.
- `set-dynamic-cast-monitor` to cast the focused monitor.
- `clear-dynamic-cast-target` to reset to an empty video stream.

You can also use these actions from the command line, for example to interactively pick which window to cast:

```
$ niri msg action set-dynamic-cast-window --id $(niri msg --json pick-window | jq .id)
```

If the cast target disappears (e.g. the target window closes), the stream goes back to empty.

All dynamic casts share the same target, but new ones start out empty until the next time you change it (to avoid surprises and sharing something sensitive by mistake).

### Indicate screencasted windows

Since: 25.02

The [`is-window-cast-target=true` window rule](./Configuration:-Window-Rules#is-window-cast-target) matches windows targeted by an ongoing window screencast. You use it with a special border color to clearly indicate screencasted windows.

This also works for windows targeted by dynamic screencasts. However, it will not work for windows that just happen to be visible in a full-monitor screencast.

```
// Indicate screencasted windows with red colors.
window-rule {
    match is-window-cast-target=true

    focus-ring {
        active-color "#f38ba8"
        inactive-color "#7d0d2d"
    }

    border {
        inactive-color "#7d0d2d"
    }

    shadow {
        color "#7d0d2d70"
    }

    tab-indicator {
        active-color "#f38ba8"
        inactive-color "#7d0d2d"
    }
}
```

Example: screencasted windows indicated with red border and shadow.

### Windowed (fake/detached) fullscreen

Since: 25.05

When screencasting browser-based presentations like Google Slides, you usually want to hide the browser UI, which requires making the browser fullscreen. This is not always convenient, for example if you have an ultrawide monitor, or just want to leave the browser as a smaller window, without taking up an entire monitor.

The `toggle-windowed-fullscreen` bind helps with this. It tells the app that it went fullscreen, while in reality leaving it as a normal window that you can resize and put wherever you want.

```
binds {
    Mod+Ctrl+Shift+F { toggle-windowed-fullscreen; }
}
```

Keep in mind that not all apps react to fullscreening, so it may sometimes look as if the bind did nothing.

### Screen mirroring

For presentations it can be useful to mirror an output to another. Currently, niri doesn't have built-in output mirroring, but you can use a third-party tool [`wl-mirror`](https://github.com/Ferdi265/wl-mirror) that mirrors an output to a window. Note that the command below requires [`jq`](https://jqlang.org/download/) to be installed.

```
binds {
    Mod+P repeat=false { spawn-sh "wl-mirror $(niri msg --json focused-output | jq -r .name)"; }
}
```

Focus the output you want to mirror, press ModP and move the `wl-mirror` window to the target output. Finally, fullscreen the `wl-mirror` window (by default, ModShiftF).

## Wiki pages

- [](/niri-wm/niri/wiki/Screencasting) Original Niri wiki page

## Usage

- [Getting Started](./Getting-Started)
- [Example systemd Setup](./Example-systemd-Setup)
- [Important Software](./Important-Software)
- [Workspaces](./Workspaces)
- [Floating Windows](./Floating-Windows)
- [Tabs](./Tabs)
- [Overview](./Overview)
- [Screencasting](./niri-screencasting.md)
- [Layer‑Shell Components](./Layer%E2%80%90Shell-Components)
- [IPC, `niri msg`](./IPC)
- [Application-Specific Issues](./Application-Issues)
- [Nvidia](./Nvidia)
- [Xwayland](./Xwayland)
- [Gestures](./Gestures)
- [Fullscreen and Maximize](./Fullscreen-and-Maximize)
- [Window Effects](./Window-Effects)
- [Packaging niri](./Packaging-niri)
- [Integrating niri](./Integrating-niri)
- [Security Model](./Security-Model)
- [Accessibility](./Accessibility)
- [Name and Logo](./Name-and-Logo)
- [FAQ](./FAQ)

## Configuration

- [Introduction](./Configuration:-Introduction)
- [Input](./Configuration:-Input)
- [Outputs](./Configuration:-Outputs)
- [Key Bindings](./Configuration:-Key-Bindings)
- [Switch Events](./Configuration:-Switch-Events)
- [Layout](./Configuration:-Layout)
- [Named Workspaces](./Configuration:-Named-Workspaces)
- [Miscellaneous](./Configuration:-Miscellaneous)
- [Window Rules](./Configuration:-Window-Rules)
- [Layer Rules](./Configuration:-Layer-Rules)
- [Animations](./Configuration:-Animations)
- [Gestures](./Configuration:-Gestures)
- [Recent Windows](./Configuration:-Recent-Windows)
- [Debug Options](./Configuration:-Debug-Options)
- [Include](./Configuration:-Include)

## Development

- [Design Principles](./Development:-Design-Principles)
- [Developing niri](./Development:-Developing-niri)
- [Documenting niri](./Development:-Documenting-niri)
- [Releasing niri](./Development:-Releasing-niri)
- [Fractional Layout](./Development:-Fractional-Layout)
- [Redraw Loop](./Development:-Redraw-Loop)
- [Animation Timing](./Development:-Animation-Timing)
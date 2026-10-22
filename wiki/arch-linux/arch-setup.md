---
title: Arch Pro Setup
description: "Flatpak-first Arch provisioning: pacman, AUR, Flatpak, system monitors, and flatpak housekeeping."
tags:
  - linux
  - arch
  - setup
  - provisioning
  - flatpak
  - pacman
  - aur
type: guide
status: draft
created: 2026-09-26
updated: 2026-10-12
related:
  - swap-encryption
  - vesktop-noctalia-theme
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document Arch Linux setup procedures"
ai-review: pending
language: en
audience: sysadmin
scope: Arch Linux desktop provisioning
keywords:
  - pacman
  - AUR
  - Flatpak
  - systemd
  - provisioning
platform:
  - Arch Linux
  - Flatpak
cssclasses:
  - nota-longa
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Arch Pro Setup

Flatpak-first, headless-safe, idempotent. Every block below is an independent paste.

> Rules used throughout: `pacman` → `--noconfirm`, `paru` → `--needed --noconfirm`, `flatpak` → `--noninteractive -y`.
> Flatpak is the default for GUI/pro apps. pacman/paru only for CLIs, runtimes and system plumbing.

---

## 1. Bootstrap

```bash
sudo pacman -Syu --needed --noconfirm --refresh
sudo pacman -S --needed --noconfirm base-devel git

# AUR helper
sudo pacman -S --needed --noconfirm paru || {
  git clone https://aur.archlinux.org/paru.git /tmp/paru && (
    cd /tmp/paru && makepkg -si --noconfirm
  ) && rm -rf /tmp/paru
}

# Flatpak + Flathub (system-wide so it works with no user session)
sudo pacman -S --needed --noconfirm flatpak
flatpak --system remote-add --if-not-exists flathub \
  https://dl.flathub.org/repo/flathub.flatpakrepo
```

---

## 2. System — pacman

```bash
sudo pacman -S --needed --noconfirm \
  curl wget rsync jq yq git-lfs github-cli 7zip unzip tree man-db man-pages \
  ripgrep-all fd bat fzf zoxide eza btop lazygit starship \
  python python-pip nodejs npm go rustup jdk-openjdk \
  podman podman-docker podman-compose podlet \
  ffmpeg imagemagick ffmpegthumbnailer \
  xdg-utils xdg-desktop-portal xdg-desktop-portal-gtk \
  noto-fonts noto-fonts-emoji ttf-jetbrains-mono
```

See `rsync-folder-merge.md` for a safe folder-merge workflow using `rsync`.

Enable services:
%
    TODO: add all my system services
%

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker "$USER"   # log out/in to apply
```

## 3. AUR — paru

```bash
paru -S --needed --noconfirm \
  ttf-jetbrains-mono-nerd \
  atuin \
  git-delta \
  procs dust duf
```

Optional / hardware:

```bash
paru -S --needed --noconfirm gpu-screen-recorder   # creative
```

---

## 4. Apps — flatpak

Vesktop replaces the official Discord flatpak: it is a native client that can be
themed from the Noctalia palette. See `vesktop-noctalia-theme.md` to wire that up.

Pick the groups you want, then run the matching line. Each one is a single
plain `flatpak install`, so nothing needs defining first.

### Daily

| App | ID |
|---|---|
| Brave | `com.brave.Browser` |
| Spotify | `com.spotify.Client` |
| Discord (Vesktop) | `dev.vencord.Vesktop` |
| Telegram | `org.telegram.desktop` |
| Slack | `com.slack.Slack` |
| Thunderbird | `org.mozilla.Thunderbird` |
| Bitwarden | `com.bitwarden.desktop` |
| Steam | `com.valvesoftware.Steam` |
| VLC | `org.videolan.VLC` |
| Flatseal | `com.github.tchx84.Flatseal` |
| Clocks | `org.gnome.clocks` |
| Calibre | `com.calibre_ebook.calibre` |
| LocalSend | `org.localsend.localsend_app` |
| Logs | `org.gnome.Logs` |

```bash
flatpak install --user --noninteractive -y flathub \
  com.brave.Browser dev.vencord.Vesktop \
  org.telegram.desktop com.slack.Slack org.mozilla.Thunderbird \
  com.bitwarden.desktop \
  com.valvesoftware.Steam org.videolan.VLC \
  com.github.tchx84.Flatseal org.gnome.clocks \
  com.calibre_ebook.calibre org.localsend.localsend_app org.gnome.Logs
```

LocalSend notes:

- AirDrop-style transfers over the local network, no account, no cloud. Peers
  must be on the same subnet, so it is useless over a headless SSH box unless
  the other devices can reach it.
- The flatpak is network-confined, but discovery is multicast/UDP broadcast.
  On a locked-down network, "Quick Save" (the save-to-disk shortcut) is more
  reliable than auto-discovery.
- It has no headless/CLI mode. If you need this from a script, use plain
  `scp`/`rsync` (both already in section 2) or `syncthing` from pacman.

### Development

No flatpak dev tools pinned. Editors, IDEs and API clients are added per project
when they are actually needed, not up front.

### Creative

| App | ID |
|---|---|
| GIMP | `org.gimp.GIMP` |
| Blender | `org.blender.Blender` |
| Inkscape | `org.inkscape.Inkscape` |
| Krita | `org.kde.krita` |
| Kdenlive | `org.kde.kdenlive` |
| Audacity | `org.audacityteam.Audacity` |
| OBS Studio | `com.obsproject.Studio` |

```bash
flatpak install --user --noninteractive -y flathub \
  org.gimp.GIMP org.blender.Blender org.inkscape.Inkscape \
  org.kde.krita org.kde.kdenlive org.audacityteam.Audacity com.obsproject.Studio
```

Just GIMP, the way you'd actually paste it:

```bash
sudo flatpak install --system --noninteractive -y flathub org.gimp.GIMP
```

---

## 5. System monitor & helpers

### Monitors — pacman

`btop` is already in section 2; this adds the rest of the CLI set.

```bash
sudo pacman -S --needed --noconfirm \
  nvtop glances ncdu bandwhich \
  lm_sensors smartmontools sysstat ethtool usbutils pciutils \
  lsof strace stress-ng powertop
```

`nvtop` needs GPU support and shows nothing useful without a driver. Skip it on
a pure-CPU box.

### Monitors — GUI (flatpak)

```bash
flatpak install --user --noninteractive -y flathub \
  io.missioncenter.MissionCenter net.nokyan.Resources org.gnome.baobab
```

| App | ID | Does |
|---|---|---|
| Mission Center | `io.missioncenter.MissionCenter` | CPU/GPU/RAM/disk/network, GNOME-style |
| Resources | `net.nokyan.Resources` | same data, different UI |
| Baobab | `org.gnome.baobab` | disk usage per folder |

### Flatpak manager

```bash
sudo flatpak install --system --noninteractive -y flathub it.mijorus.gearlever
```

| App | ID | Does |
|---|---|---|
| Gear Lever | `it.mijorus.gearlever` | install/remove/rollback versions, manage permissions |
| Flatseal | `com.github.tchx84.Flatseal` | permissions only (already in section 4) |

For one GUI across pacman, AUR *and* flatpak, `bauh` from the AUR:

```bash
paru -S --needed --noconfirm bauh
```

### Hardware inventory — AUR

```bash
paru -S --needed --noconfirm hardinfo2
```

### One-time sensor setup

Order matters: `sensors-detect` must run **before** the service is enabled,
otherwise the unit has no module list to load.

```bash
sudo sensors-detect --auto
sudo systemctl enable --now lm_sensors
sudo systemctl enable --now smartd
smartctl --scan
```

If you enabled the service first, you will see this on start:

```
lm_sensors.service: Referenced but unset environment variable evaluates to
an empty string: BUS_MODULES, HWMON_MODULES
```

Cosmetic, not an error. The unit reads `BUS_MODULES` and `HWMON_MODULES` from
`/etc/conf.d/lm_sensors`, which `sensors-detect` is what creates. Check the
file exists before worrying about the message.

That file only defines `HWMON_MODULES` unless a bus driver is genuinely needed
(`coretemp` is not one), so `BUS_MODULES` still warns on every start. Declare it
once to silence it:

```bash
sudo sh -c 'grep -q "^BUS_MODULES" /etc/conf.d/lm_sensors || echo "BUS_MODULES=\"\"" >> /etc/conf.d/lm_sensors'
sudo systemctl restart lm_sensors
```

Confirm real data is arriving — `sensors` should list your CPU, and ideally
GPU, NVMe and battery:

```bash
sensors
```

---

## 6. Flatpak housekeeping

```bash
flatpak --system update
flatpak --system repair
flatpak --system uninstall --unused
```

Grant broad filesystem access once instead of per-app:

```bash
flatpak override --user --filesystem=home com.brave.Browser
flatpak override --user --filesystem=home org.gimp.GIMP
```

List / audit:

```bash
flatpak --system list --columns=application,version
flatpak --system permissions
```

---

## 7. Notes

- **No session needed.** `--system` installs do not require a login session, so this runs over plain SSH.
- **sudo** may prompt. For true unattended runs use a passwordless sudoers drop for the exact commands, or run the whole file as root (`flatpak --system` is then implicit).
- **GPU drivers** are intentionally not in the script. On this kernel use your vendor's package (e.g. `paru -S nvidia-dkms` on NVIDIA) and rebuild the initramfs before enabling a desktop.
- **Native vs flatpak.** CLI tooling, compilers and daemons stay native (pacman/paru). Anything with a GUI and an upstream release cadence goes flatpak — fewer conflicts, clean rollback via `flatpak uninstall`.
- **Rollback.** Every flatpak line is one `flatpak uninstall <ID>` away. Native packages are harder to undo; that is the main reason flatpak is preferred here.

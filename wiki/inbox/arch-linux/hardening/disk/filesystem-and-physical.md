---
title: "Filesystem and Physical Security"
aliases:
  - Filesystem and Physical Security
  - mount options
  - filesystem hardening
  - USBGuard
  - physical security
description: >-
  Two layers that close the gaps encryption cannot: mount options that stop code executing from
  user-writable places and files being setuid there, and the physical controls — USB device
  authorization, no USB mass storage, a screen lock and a firmware password — that stop someone
  at the keyboard.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - filesystem
  - usb
  - physical-security
  - storage
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Mount options and file-permission hardening, plus physical/USB controls on a single Arch host.
  Assumes the disk itself is already encrypted — see [[Disk Encryption]].
platform:
  - arch-linux
keywords:
  - /etc/fstab
  - noexec nosuid nodev
  - tmpfs /tmp
  - sticky bit
  - chmod 1777
  - fmask dmask
  - usbguard
  - usbguard generate-policy
  - install usb-storage /bin/true
  - screen lock
  - UEFI administrator password
  - Thunderbolt DMA
related:
  - "[[Disk Encryption]]"
  - "[[Boot and Secure Boot]]"
  - "[[Kernel Hardening]]"
  - "[[Security Principles for Arch Linux]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Filesystem and Physical Security

> [!summary] One-paragraph answer
> Encryption protects data at rest; these two layers protect the running system. **Mount
> options** stop a compromised or malicious file from being executed (`noexec`), from carrying
> privilege (`nosuid`), or from being a device node (`nodev`) — starting with `/tmp` and
> `/var/tmp` on tmpfs. **Physical controls** — USBGuard, disabling USB mass storage, a screen
> lock and a firmware password — stop someone with ten minutes and your laptop.

## Context

Open this to harden a machine against local attackers and against "malware that got written to
disk". It assumes the disk is encrypted ([[Disk Encryption]]) and the boot chain is verified
([[Boot and Secure Boot]]); without those, `noexec` on `/home` is a thin wall around an open door.

## Details

### 1. Mount options

```ini
# /etc/fstab  (excerpt)
# root: no unusual privileges needed
UUID=xxxx /     btrfs rw,noatime,compress=zstd:1,subvol=@  0 0

# scratch space on tmpfs, not executable, not device nodes
tmpfs /tmp     tmpfs defaults,noexec,nosuid,nodev,size=4G   0 0
tmpfs /var/tmp tmpfs defaults,noexec,nosuid,nodev,size=2G   0 0

# ESP: no execution, locked-down modes
UUID=YYYY /efi vfat rw,noatime,fmask=0077,dmask=0077        0 2
```

Apply and verify:

```bash
sudo mount -a
findmnt -no OPTIONS /tmp          # expect noexec,nosuid,nodev
```

> [!danger] `noexec` on `/home` breaks ordinary desktop use
> Wine, Steam, PyCharm, `.NET`, user scripts and many AppImages execute from `$HOME`. Setting
> `noexec` there is a *server* choice; on a workstation it usually ends up removed again, which
> is worse than never adding it. Use it on `/tmp` and `/var/tmp`, where nothing legitimate
> executes.

### 2. Permissions and setuid

```bash
# sticky bit on world-writable directories (only owner may delete)
sudo chmod 1777 /tmp /var/tmp

# find setuid binaries — the classic privilege-escalation vector
find / -perm /4000 -type f 2>/dev/null
# a setuid binary NOT owned by root is a red flag
find / -perm /4000 -type f ! -user root 2>/dev/null
```

Filesystem-level protection for symlink/hardlink/FIFO attacks lives in the kernel sysctls
(`fs.protected_*`) — see [[Kernel Hardening]].

### 3. USB device authorization — USBGuard

USB is a DMA and HID attack surface. USBGuard authorizes each device against a policy:

```bash
sudo pacman -S usbguard
sudo usbguard generate-policy | sudo tee /etc/usbguard/rules.conf   # allow what is attached now
sudo systemctl enable --now usbguard.service

sudo usbguard list-devices
sudo usbguard allow-device <id>
usbguard watch        # observe new devices and decide
```

> [!caution] Generate the policy while your keyboard and mouse are attached
> A policy generated without your input device will refuse it on next boot and you will have no
> HID. Always `usbguard generate-policy` with everything you need plugged in.

### 4. Disable USB mass storage (blunt alternative)

If you never move data by USB stick, block the whole driver:

```ini
# /etc/modprobe.d/no-usb-storage.conf
install usb-storage /bin/true
```

This is coarser than USBGuard (HID still works; storage never mounts) and directly conflicts with
taking backups to external media — pick per machine.

### 5. Physical controls

| Control | Effect |
|---|---|
| Screen lock (auto) | closes the unlocked-session window |
| UEFI administrator password | stops boot-order and Secure Boot tampering |
| Legacy/CSM off | removes the bypass-the-bootloader path |
| Thunderbolt DMA restricted (SL2+) | blocks memory access over the port |
| Full-disk encryption | makes a powered-off laptop useless ([[Disk Encryption]]) |

```bash
# a screen lock that triggers on idle (Wayland compositor example — adapt to yours)
# e.g. swayidle + swaylock / hypridle + hyprlock, or the compositor's own idle config
```

## Gotchas

> [!warning] `noexec` and scripts with a shebang
> A script launched as `./script.sh` fails on `noexec`, but `bash script.sh` still works — because
> the interpreter is executable, not the file. Do not mistake the first for protection against the
> second.

> [!caution] USBGuard vs your own recovery media
> Acceptance is policy-based. Keep a way to boot and edit `rules.conf` if the policy is wrong —
> an unbootable, HID-less machine is a support call.

> [!note] `nodev` on `/tmp` does not stop `mknod` by root
> Mount options bound non-privileged users, not root. They are defence in depth, not a boundary
> against a root attacker.

## Verification

```bash
findmnt -no TARGET,OPTIONS /tmp /var/tmp       # noexec,nosuid,nodev
sudo usbguard list-devices                      # policy applied; rule for each device
sudo chmod -c 1777 /tmp                         # reports no change (already set)
ls -l /proc/driver/nvidia 2>/dev/null || true   # sanity that no modules were starved
```

## Related

- [[Disk Encryption]] — without it, a stolen disk defeats every local control
- [[Boot and Secure Boot]] — the boot-order and firmware layer of physical security
- [[Kernel Hardening]] — `fs.protected_*` and module blacklisting
- [[Security Principles for Arch Linux]] — why `noexec` on `/home` is deliberately not default

## Sources

- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — mount options, setuid
  auditing, USB and physical recommendations
- [fstab(5)](https://man.archlinux.org/man/fstab.5) — mount option semantics
- [USBGuard — ArchWiki](https://wiki.archlinux.org/title/USBGuard) — policy generation and the
  HID-lockout caveat
- [Unified Extensible Firmware Interface — ArchWiki](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface)
  — firmware password, CSM, TPM, Thunderbolt security levels

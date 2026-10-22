---
title: "Arch Lifecycle — Install, Maintain, Recover"
aliases:
  - Arch Lifecycle — Install, Maintain, Recover
  - arch lifecycle
  - pre-install hardening
  - maintenance and updates
  - backup and recovery
description: >-
  Security before, during and after an Arch install: verify the ISO, keep the firmware and
  package set minimal, apply updates as a single rolling transaction, monitor advisories, and
  keep a tested recovery path with 3-2-1 backups.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - backup
  - maintenance
  - updates
  - supply-chain
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Pre-installation firmware and media checks, ongoing maintenance and update hygiene, and the
  backup/recovery posture. Does not cover package signing internals or AUR build sandboxing.
platform:
  - arch-linux
  - pacman
keywords:
  - verify ISO signature
  - UEFI administrator password
  - CSM legacy boot
  - minimal install
  - pacman -Syu
  - arch-audit
  - pacman -Qkk
  - 3-2-1 backup
  - btrfs snapshots
  - snapper
  - arch-security advisories
related:
  - "[[Security Principles for Arch Linux]]"
  - "[[Disk Encryption]]"
  - "[[Boot and Secure Boot]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Arch Lifecycle — Install, Maintain, Recover

> [!summary] One-paragraph answer
> Most of a machine's security is fixed before the first boot: a firmware password, UEFI-only
> boot, a signature-verified ISO, and an install that contains only what you need. Afterwards,
> the discipline is **one full upgrade at a time** (`pacman -Syu`, never a partial upgrade),
> watching advisories, re-verifying package integrity, and keeping an offline recovery path.
> Encryption (see [[Disk Encryption]]) and the boot chain ([[Boot and Secure Boot]]) are set up
> during install and belong to their own notes.

## Context

Open this when you are about to install Arch, when you are deciding how much to install, or when
you want a repeatable maintenance routine. The three sections were originally one chapter
because they share a single idea: **the attack surface is decided by what you put on the disk,
and the ability to recover is decided before you need it.**

## Details

### 1. Before installing — firmware and media

Set an administrator/supervisor password in UEFI and disable legacy/CSM boot. This is the only
control that stops a local attacker from simply changing the boot order.

1. Enter UEFI setup (`Del`, `F2`, `F10` or `F12` during power-on).
2. Set a strong supervisor/admin password.
3. Disable **legacy/CSM** boot — UEFI only.
4. Disable or restrict **Thunderbolt DMA** (security level SL2+) and FireWire if unused.
5. Enable **TPM** if available (used for disk unlock — see [[Disk Encryption]]).

Verify the installation ISO before writing it, so a compromised mirror cannot hand you a trojan:

```bash
gpg --keyserver-options auto-key-retrieve --verify \
  archlinux-YYYY.MM.DD-x86_64.iso.sig archlinux-YYYY.MM.DD-x86_64.iso
sha256sum -c archlinux-YYYY.MM.DD-x86_64.iso.sha256
```

### 2. Install only what you need

Every package is potential attack surface and a potential update. Prefer individual packages
over meta-packages:

```bash
# deliberately short — add per need, not "everything to be safe"
pacstrap -K /mnt base linux linux-firmware vim networkmanager
```

Post-install, keep the set small. List and prune what listens or runs:

```bash
pacman -Qe                 # explicitly installed packages
systemctl list-unit-files --state=enabled
ss -tulpn                  # what is actually listening
```

### 3. Maintain — one rolling transaction at a time

Arch is rolling: **never** make a partial upgrade (`pacman -Sy pkg` or `-Sy` without `-u`). A
partial upgrade links a new library against an old binary and is the documented cause of broken
systems.

```bash
# the only supported upgrade form
sudo pacman -Syu

# read what Arch wants you to know BEFORE upgrading on a large delta
# https://archlinux.org/news/  — interrupted upgrades are the classic foot-gun
```

Check integrity of installed files and repair drift:

```bash
pacman -Qkk                       # verify installed packages' file counts
pacman -Qkk 2>&1 | grep -v ': 0 altered files'
```

Watch advisories rather than chasing CVEs:

```bash
# arch-security mailing list / advisory site
# https://security.archlinux.org/
# optional helper (extra repo)
pacman -S arch-audit && arch-audit
```

> [!warning] Do not enable blind `pacman -Syu --noconfirm` cron jobs
> Unattended *full* upgrades can reboot a machine into a broken state with nobody watching, and
> they run before you have read the news item that says the upgrade needs manual intervention.
> Automatic **signature/database** refresh is fine; automatic *upgrade* is not, on a machine you
> care about.

### 4. Recover — 3-2-1 and a tested key

Backups are a security control: ransomware and accidental `rm` are both defeated by an offline
copy. Follow the 3-2-1 rule:

| Rule | Meaning |
|---|---|
| **3** copies | the original plus two backups |
| **2** media | e.g. internal disk + external/NAS |
| **1** offsite | cloud or a second physical location |

Btrfs snapshots are fast rollback, **not** backups — they live on the same device. Use both:

```bash
pacman -S snapper snap-pac
sudo snapper -c root create-config /
sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
sudo snapper create --description "before upgrade"
```

Keep a written recovery procedure **offline**, and store the LUKS recovery key somewhere that is
not the machine it unlocks:

1. Boot the Arch ISO.
2. Unlock: `cryptsetup open /dev/sdX2 cryptlvm`.
3. Mount: `mount /dev/vg0/root /mnt`.
4. Restore from snapshot or backup.
5. Reinstall the bootloader if needed.
6. Re-enrol TPM if PCR values changed (see [[Disk Encryption]]).

## Gotchas

> [!danger] ISO signature check without the signing key
> `--verify` only means something if you actually hold Jens Kuske / Pierre Schmitz's key. Import
> it from a trusted source or check the fingerprint against `archlinux.org`. An unverified `Good
> signature` from a key you fetched over the same wire proves nothing.

> [!warning] `pacman -Qkk` noise after every upgrade
> A legitimate `-Syu` replaces hundreds of files. Run `-Qkk` *after* an upgrade settles, not
> mid-transaction, and investigate only the deviations — not the count.

> [!caution] "I have snapshots" is not a backup strategy
> Snapshots on a single btrfs device are lost with the device. Keep at least one copy you can
> reach with the machine powered off.

## Verification

```bash
# you are on a fully-upgraded, consistent system
sudo pacman -Syu          # reports nothing to do
pacman -Qkk 2>&1 | grep -v ': 0 altered files'   # no unexpected deviations
arch-audit                                    # no unpatched advisories you ignore knowingly

# the recovery path exists and is not on this machine
ls -l /var/lib/... backup mount
sudo cryptsetup luksDump /dev/sdX2 | grep -i 'Keyslots'   # recovery keyslot present
```

## Related

- [[Disk Encryption]] — set up during install; nothing here protects data at rest without it
- [[Boot and Secure Boot]] — the other pre-install decision
- [[Monitoring, Integrity and Auditing]] — turns "did anything change?" into a routine
- [[Rootkit and Backdoor Detection]] — supply-chain checks that consume this note's hygiene

## Sources

- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — verify-ISO, minimal
  install, update hygiene
- [System maintenance — ArchWiki](https://wiki.archlinux.org/title/System_maintenance) — the
  partial-upgrade rule and the news/intervention workflow
- [Arch Linux security advisories](https://security.archlinux.org/) — the advisory feed
- [Synchronize with a mirror / pacman tips](https://wiki.archlinux.org/title/Pacman) — `-Qkk`,
  package verification

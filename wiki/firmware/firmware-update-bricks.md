---
title: "Firmware Update Bricks (Linux)"
aliases:
  - Firmware Update Bricks
  - bricked after firmware update
  - BIOS update brick
  - fwupd brick
  - firmware update deaths
description: >-
  Field report on computers dying right after firmware updates in the Linux world:
  documented fwupd/LVFS bricking incidents (Framework 3.20, Lenovo ME firmware, Secure
  Boot dbx, ASUS NUC BIOS Guard), the root causes behind them, a prevention checklist,
  and the recovery ladder up to external SPI flashing.
tags:
  - firmware
  - hardware
  - uefi
  - secure-boot
  - boot
  - updates
  - linux
  - storage
  - fwupd
  - lvfs
  - spi-flash
type: dossier
status: review
confidence: high
created: 2026-10-12
updated: 2026-10-12
last_reviewed: 2026-10-12
review_after: 2026-11-12
language: en
audience: sysadmin
keywords:
  - fwupd
  - LVFS
  - UEFI capsule
  - dbx
  - Management Engine
  - AMI BIOS Guard
  - flashrom
  - CH341A
  - CH347
  - SPI flash recovery
sources:
  - "[Framework says it's addressing a BIOS update that bricked some of its older laptops](https://www.theverge.com/gadgets/982800/framework-laptop-13-amd-7040-bios-320-bricking-warranty)"
  - "[Fixing a bricked AMD 7040 series Framework 13 laptop with $20 tools](https://quantum5.ca/2026/08/16/fixing-bricked-amd-7040-series-framework-13-laptop-with-20-tools/)"
  - "[fwupd/firmware-lenovo #189 — T470: fwupdmgr update has effectively bricked my machine](https://github.com/fwupd/firmware-lenovo/issues/189)"
  - "[fwupd/firmware-lenovo #199 — T480 Me FW Downgrade: Request MeSpiLock Failed](https://github.com/fwupd/firmware-lenovo/issues/199)"
  - "[When Firmware Updates Go Wrong: How a Linux Firmware Patch Bricked My Fujitsu Media Host](https://blog.opensourceitsolutions.co.uk/firmware-update-bricked-fujitsu-linux-fix/)"
  - "[fwupd/fwupd #11031 — ASUS NUC permanent unbootable pending-update loop](https://github.com/fwupd/fwupd/issues/11031)"
  - "[Arch Wiki — fwupd](https://wiki.archlinux.org/title/Fwupd)"
  - "[Updating Secure Boot dbx with fwupd and the LVFS (hughsie)](https://blogs.gnome.org/hughsie/2020/08/17/updating-secure-boot-dbx-with-fwupd-and-the-lvfs/)"
source_retrieved: 2026-10-12
related:
  - "[[Home]]"
  - "[[boot-and-secure-boot]]"
  - "[[system-diagnostics-and-self-healing]]"
  - "[[arch-hardening-runbook]]"
  - "[[uefi-capsule-updates]]"
  - "[[secure-boot-dbx]]"
  - "[[spi-flash-recovery]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Deep research on computers dying just after firmware updates in the Linux world; compile into an Obsidian dossier following vault-conventions.md"
ai-review: pending
scope: firmware update failures and recovery on Linux
platform:
  - Linux
  - UEFI
  - fwupd
---

# Firmware Update Bricks (Linux)

> [!summary] The short version
> Firmware updates rarely kill Linux machines as a share of total updates — but when they do it is
> spectacular, concentrated in a handful of product lines, and often requires an external SPI
> programmer to undo. Documented cases: **Framework Laptop 13 (Ryzen 7040) BIOS 3.20** bricking
> boards (2026), **Lenovo ME firmware on LVFS** destabilising ThinkPads (2022–2025), **Secure Boot
> `dbx` updates** bricking Fujitsu ESPRIMOs and breaking boot on others (2025), and **ASUS NUC AMI
> BIOS Guard capsules** leaving boards in a permanent boot loop (2026). Root causes split four ways:
> vendor firmware bugs, firmware mislabeled as Linux-compatible, non-standard capsule formats, and
> boot-chain revocation updates. Prevention is mostly patience plus ESP backups; recovery goes up to
> external SPI flashing with ~US$20 of tools.

## Context

Firmware updates moved into the Linux package flow (GNOME Software, KDE Discover, `fwupdmgr`) via
`fwupd`/LVFS, so Linux users now flash BIOS/UEFI, ME, EC, Thunderbolt, NVMe and SSD firmware far more
often than they used to. Most updates succeed silently; the failures that make the news are the ones
that break **the machine itself** — the one thing a package manager is never supposed to touch.

> [!important] Read this first
> The OS hands the flash to the firmware: fwupd stages a capsule on the ESP, then on reboot the
> *firmware itself* writes the SPI flash with the OS long out of the loop. That is why failures
> always read as "it rebooted and never came back" — and why interrupting a flash screen is the
> single most common way to turn a soft failure into a hard brick.

## Details

### The Linux firmware-update pipeline

| Channel | Mechanism | Failure characteristics |
|---|---|---|
| fwupd + LVFS | Signed metadata + capsules from the Linux Vendor Firmware Service, applied by firmware on reboot (via `fwupdx64.efi`, chainloaded through shim under Secure Boot) | QA is vendor-supplied; mislabeled firmware; firmware that never clears a failed capsule request |
| Vendor Linux / EFI tools | `fwupdtool install-blob`, vendor EFI-shell packages, ASUS `iFlashVLnx64` | Kernel-module tools blocked by Secure Boot + lockdown; non-FMP capsule formats |
| Windows-only tools | Vendor updater run under Windows (WD Dashboard, Samsung Magician, Lenovo Vantage) | Outside Linux visibility; same bricking class |
| flashrom | Direct SPI flashing | User-error risk; also the *rescue* path when nothing else works |

### Documented cases

#### Framework 13 AMD 7040: BIOS 3.20 (2026)

- Framework emailed owners urging BIOS 3.20 (security fixes, new features). Flashing from 3.18, many
  machines **hung on the BIOS flash screen with corrupted graphics** and never recovered — reported
  on **both Windows and Linux**.
- **In-warranty** boards were replaced; **out-of-warranty** owners initially told to buy a new
  mainboard (≈CA$500). Public pressure (Hacker News, Lobsters, Ars Technica, The Verge) forced
  Framework to extend **out-of-warranty replacements** and announce **Crisis Recovery Mode** (already
  on Framework Desktop; promised to Laptop 12/13/16 by end of 2026) — a feature 2004-era ASUS boards
  already had ("CrashFree BIOS 2").
- One Debian user recovered his board with **US$20 of tools**: a CH347 SPI programmer + WSON8
  pogo-pin probe + 1.8 V level shifter, flashing the 32 MiB Winbond `W25Q256JW` in-circuit with
  `flashrom`, extracting the raw BIOS from Framework's `.cap` with a patched `InsydeH2O-extractor`.
  The board has an **unpopulated SPI header** and silkscreen for a socketed chip it never got.
- This model had similar bad-flash reports back to at least March 2025; Framework 16
  (BIOS `LFKN6.04.01`) also bricked a Kubuntu user.

> [!caution] Side effects of a full SPI flash
> One documented recovery also wiped UEFI NVRAM boot entries and the serial/UUID values stored
> alongside the BIOS image (`System SN 1234567890`). Budget for reinstalling the bootloader
> (`grub-install` / `bootctl reinstall`) and re-activating Windows after any deep flash.

#### Lenovo ThinkPad ME firmware via LVFS (2022–2025)

- Series of "fwupdmgr update has effectively bricked my machine" issues in `fwupd/firmware-lenovo`:
  [T470 #189](https://github.com/fwupd/firmware-lenovo/issues/189) (repeated black screens/freezes,
  paperclip resets), [T480 #199](https://github.com/fwupd/firmware-lenovo/issues/199)
  (`Me FW Downgrade — Request MeSpiLock Failed`, **still open**), and ThinkPad P1 Gen 5
  [@387](https://github.com/fwupd/firmware-lenovo/issues/387) ("Failed to Recover ME Firmware").
- **Root cause:** Lenovo's Intel **Management Engine (ME)** firmware published on LVFS is tagged as
  Linux-compatible but only applies correctly through the Windows updater path. Staging it together
  with the BIOS capsule can leave a mismatched ME/BIOS pair that hangs or reset-loops on every boot;
  the ME also locks against the downgrade you would use to escape (`MeSpiLock`).

#### HP ProBook 445 G9: boot loop after fwupdmgr update

- [`fwupd/missing-firmware-hp#6`](https://github.com/fwupd/missing-firmware-hp/issues/6): HP splash for
  2 seconds, then endless reboot. CMOS and battery-drain tricks failed — the classic pattern where the
  flash "succeeded" but firmware validation rejects the result at boot time.

#### Fujitsu ESPRIMO D556: Secure Boot dbx update brick (2025)

- A routine `fwupd` update delivered the **UEFI dbx (revocation list)**; older Fujitsu firmware
  mishandled the new entries and the machine went no-POST. **The same update bricked Fujitsu systems
  worldwide, most via Windows Update KB5060533** — same mechanism, both OSes.
- Recovery required a physical **BIOS recovery jumper**, a FreeDOS USB stick, and the vendor's
  "UEFI DBX Restore Tool". The update is offered again after recovery (legit `fwupdmgr ignore
  <device>` use case).

#### Secure Boot dbx and the CA-2023 rollout

- `dbx` is a **one-way revocation list** of bootloaders. Applying it blindly bricks machines whose
  ESP still holds revoked shim/grub — even a fresh installer can't boot afterwards. fwupd author
  Richard Hughes warned about this in 2020; fwupd now checks the ESP before applying.
- 2023–2025 rollouts exposed a decade of firmware debt: boards that silently ignore updates, boards
  that brick when a dbx is applied, NVRAM filling to ~95% (Lenovo Y580), and boot chains that just
  stop working until Secure Boot keys are reset to factory.

#### ASUS NUC 15 Pro+: AMI BIOS Guard capsule → permanent boot loop (2026)

- [`fwupd/fwupd#11031`](https://github.com/fwupd/fwupd/issues/11031): the vendor `.cap` is an **AMI
  BIOS Guard container** (`AMI_BIOS_GUARD_FLASH_CONFIGURATION`, AMIPFAT), **not** a standard FMP
  capsule. fwupd wrapped it in a generic capsule header and staged it; the firmware refuses it, then
  **retries forever on every boot and never clears the `OsIndications` request** — pre-empting
  *every* on-board recovery path (jumper config mode, EZ Flash, recovery sticks). Only an external
  SPI programmer can clear the live variable store.
- Open question left with maintainers: should `uefi_capsule` advertise this device as `Updatable` at
  all, and should firmware ever be allowed to retry a failed capsule indefinitely?

#### Dell: the UEFI capsule toggle has a name

- Dell XPS 9710: one BIOS update **bricked both of a user's laptops**; the documented fix was
  entering BIOS and disabling **"Enable UEFI Capsule Firmware Updates"**, plus Dell's Ctrl+Esc
  USB **BIOS recovery** mode. Dell survives bad flashes because recovery logic ships in firmware —
  something thin-and-light boards like Framework's omitted.

#### Storage deaths tied to firmware

- **Samsung 980 Pro 2TB** (firmware `3B2QGXA7`, 2021 batches): drives silently enter an
  **irrecoverable failed state**; Samsung's only fix was a *newer* firmware (`5B2QGXA7`). Mass
  failures documented across sysadmin forums and Puget Systems.
- **SanDisk Extreme V2 / Extreme Pro V2** portable SSDs (2023): shipping firmware wiped data and
  made drives unreadable; WD only admitted it after articles, lawsuits and recovery-lab reports.
- **Intel SSDs** dead after firmware updates (historical hardforum threads); most SSD firmware
  updates remain Windows-only, which is why the sector keeps producing guides and scripts to do it
  from Linux.

#### Counter-example worth remembering

XDA's "I blamed a firmware update for bricking my laptop, but I couldn't have been more wrong": after
a Framework firmware update the battery cycled charge/discharge and `fwupdmgr get-history` showed
**EFI error code 21** — every clue pointed at firmware. The culprit was a **bad USB-C cable**.
Attribution failure runs both ways: some "bricked by update" stories are coincidence, and silently
failing laptops are routinely blamed on whatever update ran last.

### Root causes

1. **Broken vendor firmware images** — Framework 3.20's flasher rendering garbage from memory; HP
   ProBook boot loops. LVFS validation is the vendor's own word, thinner than Windows Update/oem QA.
2. **Mislabeled firmware** — "Windows only" images shipped as Linux-compatible (Lenovo ME on LVFS).
3. **Non-standard capsule formats** — AMI BIOS Guard/AMIPFAT wrapped as FMP capsules; worst case the
   firmware never clears the pending request → permanent boot loop (ASUS NUC).
4. **Boot-chain revocation (`dbx`)** — global, one-way, applied by every OS via the same UEFI
   mechanism; older firmware mishandles it (Fujitsu, Ubuntu 23.10 case, Framework "owner-controlled
   Secure Boot" breakage).
5. **Power/process loss in the critical window** — the OS hands off to firmware; forced reset, a
   stuck EC, or a dying battery mid-flash aborts the write.
6. **No recovery path on the board** — single-bank SPI flash, no vendor rescue mode, WSON chips with
   nothing to clip, absent flash headers, soldered chips despite socket silkscreen.
7. **ESP/NVRAM fragility on Linux setups** — bind-mounted ESPs, lowercase `efi/` directories, missing
   shim under Secure Boot, enabled `Boot Order Lock`, near-full efivar stores: all turn a staged
   update into a failed-then-retried one.
8. **ME/EC subsystem handshake** — partial ME writes leave "Failed to Recover ME" states that behave
   like bricks on every boot.

### Is this a Linux problem?

No — but Linux has a specific exposure profile:

- The same mechanisms **brick Windows machines constantly** (KB5060533/Fujitsu, Dell XPS, Lenovo
  Vantage). Firmware updates are the highest-risk operation any OS performs; Linux just moved them
  into the package manager, so they happen more often.
- Linux aggravators: LVFS is the *only* update avenue for many users and its QA is vendor-supplied;
  fwupd exposes firmware OEMs never tested on Linux (Lenovo ME); support is more dismissive of
  non-Windows users; and vendor BIOS-recovery utilities rarely run on Linux.
- Mitigation: Linux is **also** where the rescue happens — `flashrom`, ch341a/ch347 drivers and
  pogo-pin probes turn a bricked board into a $20 DIY job.

## Issues watchlist

Live tracker — update `updated:` and this table when statuses change.

| Issue | Device / platform | Trigger | State (2026-10-12) |
|---|---|---|---|
| [firmware-lenovo #199](https://github.com/fwupd/firmware-lenovo/issues/199) | Lenovo T480 | ME firmware via LVFS (`MeSpiLock Failed`) | open — last activity 2025-07 |
| [firmware-lenovo #387](https://github.com/fwupd/firmware-lenovo/issues/387) | ThinkPad P1 Gen 5 | ME + system firmware combo → "Failed to Recover ME" | open |
| [missing-firmware-hp #6](https://github.com/fwupd/missing-firmware-hp/issues/6) | HP ProBook 445 G9 | fwupdmgr update → boot loop | open |
| [fwupd/fwupd #11031](https://github.com/fwupd/fwupd/issues/11031) | ASUS NUC 15 Pro+ | BIOS Guard capsule → permanent pending-update loop | open (2026-09) |
| [Framework 3.20 thread](https://community.frame.work/t/upgrading-to-bios-3-20-on-ryzen-7040-series-may-brick-your-machine/84031) | Framework 13 (Ryzen 7040) | BIOS 3.20 flash hangs on Windows + Linux | vendor: out-of-warranty replacements; Crisis Recovery Mode ETA end of 2026 |
| [Cost of a bad flash: the chip](https://quantum5.ca/2026/08/16/fixing-bricked-amd-7040-series-framework-13-laptop-with-20-tools/) | Framework 13 (6040/7040) | general bad-flash recovery with CH347 + pogo pins | recovered |

## Prevention checklist

```bash
# Inspect before updating
fwupdmgr get-devices          # what is updatable
fwupdmgr refresh
fwupdmgr get-updates          # versions, urgency, requirements
fwupdmgr get-history          # previous updates + EFI error codes
```

- **Never flash on battery only** — AC power required; fwupd refuses otherwise.
- **Back up the ESP first**: `sudo tar -czf /tmp/efi-$(date +%F).tar.gz /efi` (or `/boot`).
- Verify the Arch Wiki prerequisites: booted in UEFI mode, `efivarfs` readable, ESP mounted,
  `udisks2` running, `EFI` directory uppercase on the ESP.
- Secure Boot on: make sure `shim` is present, or sign `fwupdx64.efi` yourself and set
  `DisableShimForSecureBoot=true`.
- **Wait 1–2 weeks after a vendor publishes a BIOS upgrade** — forums and the LVFS triage do the QA.
- Know the board's recovery story *before* updating: Lenovo Fn+R, Dell Ctrl+Esc, HP Sure Start,
  dual BIOS, flash header?
- On older machines, treat **dbx updates** as the riskiest kind: update shim/GRUB/systemd-boot
  *before* the dbx, never after; per-device `fwupdmgr update <id>`; `fwupdmgr ignore <id>` to skip.
- ESP oddities: explicit `EspLocation=` in `/etc/fwupd/fwupd.conf` if you bind-mount; update one
  device at a time when troubleshooting.
- Update hung at the flasher? **Be patient** — ThinkPads run 10+ minutes with a black screen;
  interrupting is the most common cause of real bricks. Only force-reset after the fan settles.

## Recovery ladder

1. **Wait it out** — give the flasher ≥20 minutes on AC before anything else.
2. **CMOS/EC reset** — unplug AC, disconnect battery for 30 minutes (this un-bricked a "nearly
   bricked" Framework 13); hold power 30–40 s to drain the EC.
3. **Vendor rescue modes** — Lenovo `Fn+R`, Dell `Ctrl+Esc` + USB image, HP Sure Start, ASUS
   recovery jumper: built for exactly this.
4. **Boot-chain repair** — reset Secure Boot keys to factory, reinstall the bootloader, recreate
   NVRAM entries with `efibootmgr`.
5. **External SPI flash** (~US$20, all from Linux):
   - CH347 (or CH341A **+ 1.8 V level shifter**) + WSON8 pogo-pin probe / SOIC clip;
   - read the chip 2–3× with `flashrom --programmer ch347_spi -r backup.bin`, verify hashes match
     (this backup may hold serial/UUID data you need later);
   - extract the raw BIOS from the vendor `.cap` (`InsydeH2O-extractor` forks build on Linux) and
     write with `flashrom ... -nNw wanted.bin`, then verify by re-reading.
6. **RMA / replacement** — if the brick followed a vendor-*recommended* update, push back; Framework
   reversed its out-of-warranty policy under public pressure.

> [!danger] External flashing hazards
> Cheap CH341A clones drive the data pins at 5 V even on 3.3 V chips — measure before plugging in.
> A 1.8 V SPI chip powered at the wrong voltage can die permanently. Double-check pin 1 orientation
> (white dot) before energising anything.

## Gotchas

- `dbx` updates are **one-way**: you cannot downgrade a revocation list. On old hardware skip them.
- The ME and BIOS capsules are often staged **together**; a failing ME write can take the whole pair
  down. On Lenovo, update ME through the vendor's Windows path instead of LVFS if at all possible.
- A successful flash can still wipe UEFI NVRAM: keep an ESP backup and a bootloader reinstall at
  hand.
- fwupd's `Linux-Firmware-Updater` UEFI boot entry depends on boot order; vendors ship **Boot Order
  Lock** default-on, which silently blocks the capsule from running.
- Read-only/bind-mounted ESPs make fwupd mis-detect the ESP and stage the capsule in the wrong tree
  (read-only filesystem errors; `umount /boot` workaround).

## Related

- [[boot-and-secure-boot]] — the sbctl / systemd-boot / Secure Boot chain this risk attaches to
- [[system-diagnostics-and-self-healing]] — boot-time triage and recovery on a real host
- [[arch-hardening-runbook]] — host hardening that includes boot-chain review
- Placeholders to grow later: [[uefi-capsule-updates]] · [[secure-boot-dbx]] · [[spi-flash-recovery]]

## Sources

- The Verge — [Framework 3.20 bricking + Crisis Recovery Mode](https://www.theverge.com/gadgets/982800/framework-laptop-13-amd-7040-bios-320-bricking-warranty)
- Quantum — [Fixing a bricked AMD 7040 Framework 13 with \$20 tools](https://quantum5.ca/2026/08/16/fixing-bricked-amd-7040-series-framework-13-laptop-with-20-tools/)
- Ars Technica — [Framework responds to bricking reports](https://arstechnica.com/gadgets/2026/08/framework-responds-to-complaints-that-bios-update-bricked-ryzen-7040-laptops/)
- GitHub — [fwupd/firmware-lenovo #189](https://github.com/fwupd/firmware-lenovo/issues/189) · [#199](https://github.com/fwupd/firmware-lenovo/issues/199) · [#387](https://github.com/fwupd/firmware-lenovo/issues/387)
- GitHub — [fwupd/missing-firmware-hp #6](https://github.com/fwupd/missing-firmware-hp/issues/6)
- GitHub — [fwupd/fwupd #11031 (ASUS NUC BIOS Guard loop)](https://github.com/fwupd/fwupd/issues/11031)
- Open Source IT Solutions — [Fujitsu ESPRIMO bricked by a dbx update (Ubuntu)](https://blog.opensourceitsolutions.co.uk/firmware-update-bricked-fujitsu-linux-fix/)
- hughsie — [Updating Secure Boot dbx with fwupd and the LVFS](https://blogs.gnome.org/hughsie/2020/08/17/updating-secure-boot-dbx-with-fwupd-and-the-lvfs/)
- Arch Wiki — [fwupd](https://wiki.archlinux.org/title/Fwupd)
- Puget Systems — [Samsung 980 Pro critical firmware advisory](https://www.pugetsystems.com/support/guides/critical-samsung-ssd-firmware-update/)
- Ars Technica — [SanDisk extreme SSDs still wiping data after firmware fix](https://arstechnica.com/gadgets/2023/08/sandisk-extreme-ssds-are-still-wiping-data-after-firmware-fix-users-say/)
- XDA — [I blamed a firmware update for bricking my laptop (it was the cable)](https://www.xda-developers.com/i-thought-bricked-my-framework-laptop-by-updating-it/)
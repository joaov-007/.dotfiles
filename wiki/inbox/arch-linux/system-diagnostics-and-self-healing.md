---
title: "System Diagnostics and Self-Healing on Arch Linux"
aliases:
  - system doctor
  - linux doctor
  - self-healing linux
  - ACPI BIOS errors
  - firmware bug diagnosis
  - journalctl triage
  - system health check
description: >-
  A layered playbook for finding what is actually wrong on a running Arch host, and for
  automating the response. Covers the journalctl/dmesg triage order, decoding ACPI and BIOS
  firmware errors, machine-check and SMART hardware faults, the self-healing primitives Linux
  really has (systemd restart, watchdogs, kdump, filesystem scrub), and a worked example from
  host bacon.
tags:
  - arch-linux
  - linux
  - troubleshooting
  - self-audit
  - diagnostics
  - self-healing
  - acpi
  - firmware
  - hardware
  - watchdog
  - kernel
  - systemd
  - sysctl
  - monitoring
  - logging
type: guide
status: needs-action
created: 2026-10-12
updated: 2026-10-12
last_reviewed: 2026-10-12
review_after: 2027-04-12
language: en
platform:
  - Arch Linux
  - systemd
scope: >-
  Single-host diagnosis and automated recovery on Arch: boot logs, firmware/ACPI errors,
  hardware fault reporting, systemd failure triage, and the self-healing primitives
  (restart, watchdog, crash capture, filesystem repair). Not a debugging guide for a
  single user-space program.
audience: sysadmin
keywords:
  - systemctl --failed
  - journalctl -b -p err
  - journalctl -k -b -1
  - dmesg_restrict
  - ACPI BIOS Error
  - AE_ALREADY_EXISTS
  - AE_NOT_FOUND
  - acpi_osi
  - acpi_enforce_resources
  - fwupdmgr get-updates
  - rasdaemon
  - ras-mc-ctl --summary
  - smartctl -H
  - smartd
  - RuntimeWatchdogSec
  - RebootWatchdogSec
  - wdctl
  - kernel.panic
  - kdump crashkernel
  - btrfs scrub
  - fsck.mode=force
  - systemd-coredump
  - coredumpctl
sources:
  - "[ACPI modules — Arch Wiki](https://wiki.archlinux.org/title/ACPI_modules)"
  - "[DSDT — Arch Wiki](https://wiki.archlinux.org/title/DSDT)"
  - "[S.M.A.R.T. — Arch Wiki](https://wiki.archlinux.org/title/S.M.A.R.T.)"
  - "[Kdump — Arch Wiki](https://wiki.archlinux.org/title/Kdump)"
  - "[systemd-system.conf(5) — Manager configuration (watchdog)](https://www.freedesktop.org/software/systemd/man/latest/systemd-system.conf.html)"
  - "[sysctl/kernel.rst — Linux kernel admin guide (kernel.panic, panic_on_oops)](https://docs.kernel.org/admin-guide/sysctl/kernel.html)"
source_retrieved: 2026-10-12
related:
  - "[[arch-system-audit]]"
  - "[[Monitoring, Integrity and Auditing]]"
  - "[[Arch Lifecycle — Install, Maintain, Recover]]"
  - "[[kernel-dev-debugging]]"
  - "[[kernel-initramfs]]"
  - "[[systemd-and-sandboxing]]"
  - "[[Vault Conventions]]"
cssclasses:
  - reference
# --- host-specific findings (host bacon, 2026-10-12) ---
findings:
  - id: acpi-dsdt-duplicates
    severity: info
    status: open
    detail: 33 ACPI BIOS Error lines, all AE_ALREADY_EXISTS/AE_NOT_FOUND in the Acer DSDT; cosmetic
  - id: sysctl-inline-comment
    severity: medium
    status: open
    detail: /etc/sysctl.d/99-hardening.conf:11 puts a comment on the value line, failing systemd-sysctl
  - id: acpi-call-module-missing
    severity: medium
    status: open
    detail: acpi_call-dkms has no module built for 7.2.9 and Secure Boot is on; modules-load fails
  - id: tpm-nvpcr-unsupported
    severity: low
    status: open
    detail: systemd NvPCR services fail on this TPM; unrelated to boot success
  - id: audit-backlog
    severity: low
    status: open
    detail: audit_backlog_limit=64 is too small for the hardening rule set; audit_lost climbing
  - id: no-automated-recovery
    severity: medium
    status: open
    detail: RuntimeWatchdogSec=0 and kernel.panic=0 — a hang or panic does not self-recover
actions:
  - id: fix-sysctl-inline-comment
    status: pending
    command: move the comment on line 11 of /etc/sysctl.d/99-hardening.conf to its own line
  - id: decide-acpi-call
    status: pending
    command: rebuild+sign acpi_call via DKMS/MOK, or delete /usr/lib/modules-load.d/acpi_call.conf
  - id: raise-audit-backlog
    status: pending
    command: set backlog_limit in /etc/audit/auditd.conf, then restart auditd
  - id: arm-watchdog
    status: pending
    command: RuntimeWatchdogSec=30s in /etc/systemd/system.conf.d/watchdog.conf
  - id: panic-autoreboot
    status: pending
    command: set kernel.panic=10 in /etc/sysctl.d/99-hardening.conf
---

# System Diagnostics and Self-Healing on Arch Linux

> [!summary] The one-paragraph answer
> Linux does not heal itself the way a consumer OS pretends to. You build a loop:
> **detect** (read the right log, at the right layer), **interpret** (a firmware *bug* is not
> failing hardware), **respond** (restart, spare, repair, or reboot), and **recover** (a tested
> path back). Diagnosis is five commands and a layered mental model; the "self-healing" is a
> handful of systemd and kernel knobs — `Restart=`, the watchdog, `kernel.panic`, kdump, and
> scheduled `scrub`/`fsck`. On host `bacon` this guide found five real defects by reading the
> journal, not by guessing.

---

## Context

You open the machine and something is wrong — a service died, a device vanished, the boot log
is bleeding red text, or it just feels slow. You want to know *what* broke and you want the
machine to stop needing you next time. Two different jobs:

1. **Diagnosis** — turn "it's broken" into a specific, sourced sentence.
2. **Self-healing** — automate the response so a fault degrades instead of stopping.

The trap is treating the first as a keyword search. Kernel logs are layered, and each layer has
its own tool. Read the wrong layer and you chase a harmless firmware warning while the actual
fault — a failed unit, a dying NVMe, a bad `/etc` line — stays invisible.

> [!important] Firmware "errors" are usually bugs in the *vendor's* firmware, not failures
> `ACPI BIOS Error (bug): ...` is the kernel telling you the motherboard's ACPI tables are
> malformed. On its own it changes nothing. It only matters when it correlates with a device or
> function that actually stopped working.

---

## Details

### 1. The layer model — where an error can even appear

| Layer | Fails when | Reported in | Primary tool |
|---|---|---|---|
| Firmware (BIOS/UEFI, ACPI, ME) | vendor tables are malformed | kernel log, first ~2 s | `journalctl -k \| grep -i acpi` |
| Kernel (drivers, MCE, oops) | bug, hardware fault, bad cmdline | kernel ring buffer | `journalctl -k -b -1`, `ras-mc-ctl` |
| systemd (units, boot) | a service crashed or misconfigured | journal, unit state | `systemctl --failed` |
| Hardware (disk, RAM, sensors) | media wear, ECC, thermals | `smartd`, EDAC, `sensors` | `smartctl`, `ras-mc-ctl` |
| User-space apps | their own bug | journal, `coredumpctl` | `journalctl -u <unit>` |

Work top-down. The first layer that shows a *correlated* symptom is your suspect; everything
above it is usually noise.

### 2. The five commands that answer 90% of "what's wrong"

```bash
systemctl --failed --no-legend          # units that are actually broken
journalctl -b -p err --no-pager         # every error-level line this boot
journalctl -k -b -p warning --no-pager  # kernel errors and warnings
journalctl --list-boots                 # boot index, for reaching into the past
systemd-analyze critical-chain          # what actually delayed the boot
```

> [!warning] `dmesg` may refuse to run
> With `kernel.dmesg_restrict=1` (the Arch hardening default, and set on `bacon`), a normal user
> gets `dmesg: read kernel buffer failed: Operation not permitted`. Use `journalctl -k` (the same
> data, permission-checked), or `sudo dmesg`. Do not "fix" it by setting `dmesg_restrict=0`.

Make the journal survive reboots, or the command above can only ever see the current boot:

```bash
sudo mkdir -p /etc/systemd/journald.conf.d
printf '[Journal]\nStorage=persistent\n' | sudo tee /etc/systemd/journald.conf.d/persistent.conf
sudo systemctl restart systemd-journald
journalctl --list-boots        # now shows -1, -2, ...
```

### 3. Firmware layer — reading ACPI and BIOS errors

Collect them:

```bash
journalctl -k -b --no-pager | grep -E 'ACPI (BIOS )?Error|Firmware Bug'
journalctl -k -b --no-pager -g 'ACPI|BIOS|Firmware'          # broader
sudo dmidecode -t bios | grep -E 'Version|Release Date'      # what firmware you run
sudo acpidump -b && iasl -d DSDT.dat                          # decompile, only if you must
```

Decode the message to its `AE_` code — that is the whole diagnosis:

| Message shape | Code | Meaning | Action |
|---|---|---|---|
| `Failure creating named object [...], AE_ALREADY_EXISTS` | `AE_ALREADY_EXISTS` | the DSDT defines the same object twice (firmware bug) | usually ignore |
| `Could not resolve symbol [...], AE_NOT_FOUND` | `AE_NOT_FOUND` | a method references an object that does not exist | ignore unless the device is present |
| `ACPI Error: AE_ALREADY_EXISTS, During name lookup/catalog` | `AE_ALREADY_EXISTS` | same duplicate-object bug, second half of the pair | ignore |
| `ACPI: EC: input buffer is not empty, aborting transaction` | — | embedded-controller/BIOS handshake bug, can break battery or brightness | BIOS update; `acpi_enforce_resources=lax`; last resort `acpi=off` |
| `ACPI BIOS Warning (bug): Optional FADT field ...` | — | cosmetic spec violation | ignore |

**The escalation rule.** Ignore an ACPI bug *unless* it correlates with a symptom you can see:
a device that no longer appears (`lspci -tv`, `lsusb -t`), a suspend/resume that hangs, broken
fan/thermal/battery, or a boot loop. If it does correlate, in order of preference:

1. **Update the firmware.** `fwupdmgr get-updates` then `fwupdmgr update` (needs the vendor to
   publish to LVFS; many laptops do). Otherwise the OEM's update utility.
2. **Kernel workarounds** for the specific symptom — `acpi_osi="Windows 2020"` to change what OS
   the firmware thinks it is talking to, `processor.max_cstate=` / `intel_idle.max_cstate=` /
   `idle=nomwait` for boot loops and C-state instability. Test one at a time.
3. **Override the DSDT** — compile a fixed table and load it. It is a genuine last resort: a bad
   override bricks the boot. See the Arch Wiki *DSDT* page; keep a recovery USB.

> [!caution] `acpi=off` is a diagnostic, not a fix
> It disables all ACPI power management — no battery reporting, no thermal control, no suspend.
> Boot with it once to prove the firmware is at fault, then turn it back off.

Noise management: keep the warnings visible in the journal, but keep them out of your face.
An alias is honest; `loglevel=3` hides real errors too.

```bash
alias acpi-check='journalctl -k -b --no-pager | grep -E "ACPI (BIOS )?Error|Firmware Bug"'
```

### 4. Kernel and hardware-fault layer

```bash
journalctl -k -b -p err --no-pager | grep -iE 'ata|nvme|i/o error|medium error|machine check|mce'
journalctl -k -b -1 --no-pager                  # the boot before a crash
coredumpctl list                                # user-space crashes, with backtraces
```

Machine-check exceptions (bad RAM, CPU cache, PCIe) are the ones worth acting on. Install the
RAS daemon — `mcelog` is legacy, `rasdaemon` is the maintained path:

```bash
sudo pacman -S rasdaemon && sudo systemctl enable --now rasdaemon
ras-mc-ctl --summary        # "No Memory errors" is the healthy output
ras-mc-ctl --errors         # the events, if there are any
```

Storage wear and failure prediction are S.M.A.R.T. Install it and let `smartd` watch in the
background; run a short test now and then:

```bash
sudo pacman -S smartmontools
sudo smartctl -H /dev/nvme0                          # PASSED / FAILED
sudo smartctl -t short /dev/nvme0 && sudo smartctl -l selftest /dev/nvme0
sudo systemctl enable --now smartd                   # DEVICESCAN -a by default
```

> [!warning] `smartctl` needs root
> `--scan` works unprivileged, but the health read does not. A monitoring timer must run as
> root — see §6e.

### 5. systemd layer — the failure ledger

```bash
systemctl --failed
systemctl status systemd-sysctl.service        # the "why" is in the last 10 journal lines
journalctl -u systemd-sysctl.service -b -p err --no-pager
systemd-analyze verify /etc/systemd/system/my.service   # syntax check before you ship a unit
```

> [!important] A failed `systemd-sysctl.service` is almost always a config typo
> `/etc/sysctl.d/*.conf` is not a comment-capable format for values. Everything after `=` is the
> value, **including an inline `# comment`**. `kernel.modules_disabled = 0  # note` tries to set
> the value to `0  # note` and fails with `Invalid argument`. Comments must be on their own line.

### 6. The self-healing primitives

There are exactly four ways Linux recovers without you, plus the detection loop that decides
when to use them:

**a. Restart the service.** For anything that can be restarted, ask systemd to do it:

```ini
# /etc/systemd/system/myapp.service.d/restart.conf
[Unit]
StartLimitIntervalSec=60
StartLimitBurst=5

[Service]
Restart=on-failure
RestartSec=5s
```

> [!warning] Always cap the restarts
> Without `StartLimitBurst`, `Restart=always` on a broken unit forks forever. systemd's own
> `StartLimitBurst` guard is what stops a crash loop from becoming a fork bomb.

**b. Watchdog — reboot a machine that has stopped responding.** systemd pets `/dev/watchdog`;
if userspace or the kernel wedges, the hardware reboots.

```ini
# /etc/systemd/system.conf.d/watchdog.conf
[Manager]
RuntimeWatchdogSec=30s
RebootWatchdogSec=5min
```

```bash
wdctl                    # shows the active watchdog and its timeout
systemctl show -p RuntimeWatchdogUSec
```

> [!danger] A watchdog reboots your machine
> If the timeout is too short, a busy boot or a long suspend can trip it. Start at 30 s, confirm
> it survives a busy workload, and know that this is a *hardware* reset, not a graceful one.

**c. Crash capture and automatic reboot.** A panic should not leave a hung box.

```bash
# /etc/sysctl.d/99-recovery.conf
kernel.panic=10          # reboot 10s after a panic
kernel.panic_on_oops=1   # (opt-in) treat an oops as a panic — only after testing
```

For *evidence* rather than a silent reboot, add kdump: a second kernel in reserved memory that
captures `/proc/vmcore`. Minimum path (Arch Wiki *Kdump*): install `kexec-tools`, add
`crashkernel=512M` to the kernel cmdline, load the capture kernel with a `kdump.service`, and
collect with `makedumpfile`. The AUR helpers `simple-kdump` / `kdumpst` automate it.

**d. Filesystem self-healing.** ext4 can remount read-only instead of corrupting further;
btrfs has scrub; both belong on a schedule.

```bash
# ext4: /etc/fstab options → errors=remount-ro   (the default, keep it)
# force a check at next boot:
#   kernel cmdline fsck.mode=force fsck.repair=yes
sudo btrfs scrub start -Bd /        # -B background, -d detached; checksums vs mirror
sudo btrfs scrub status /
sudo btrfs device stats /           # any counter above 0 is a real event
```

**e. The detection loop.** The "self" in self-healing is a timer that runs the diagnostic and
tells you when it changes. [[scripts/system-doctor.sh]] is a read-only collector that exits
non-zero when it finds something:

```ini
# /etc/systemd/system/system-doctor.service
[Unit]
Description=Read-only host health check

[Service]
Type=oneshot
ExecStart=/usr/bin/bash /home/joaov/Projects/Wiki/scripts/system-doctor.sh -q
```

```ini
# /etc/systemd/system/system-doctor.timer
[Unit]
Description=Daily host health check

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl enable --now system-doctor.timer
journalctl -u system-doctor.service        # the report lands in the journal
```

**f. Updates are not a self-healing loop.** On a rolling release, an unattended `pacman -Syu`
halfway through a transaction is a partial upgrade — the exact failure mode Arch warns about.
Detect, notify, and apply on purpose:

```bash
checkupdates                       # what a sync would bring, without touching the DB
arch-audit                         # security advisories against installed versions
```

The full maintenance and rollback posture lives in
[[Arch Lifecycle — Install, Maintain, Recover]].

### 7. Worked example — host `bacon`, 2026-10-12

Everything below came from the read-only commands above on this machine (Acer Aspire A315-58,
BIOS V1.35, kernel 7.2.9-arch1-1). This is what "the doctor" actually found.

**Firmware.** 33 kernel lines are ACPI firmware bugs, in two families:

```
ACPI BIOS Error (bug): Failure creating named object [\_SB.PC00.XHCI.RHUB.HS01._UPC], AE_ALREADY_EXISTS
ACPI BIOS Error (bug): Could not resolve symbol [\_SB.PC00.DGPV], AE_NOT_FOUND
ACPI Error: Aborting method \_SB.PC00.PEG0.PCRP._ON due to previous error (AE_NOT_FOUND)
```

- `HS01`–`HS14` `_UPC`/`_PLD` duplicates: the DSDT declares the USB port descriptors twice.
  **Cosmetic** — the USB ports work.
- `DGPV` `AE_NOT_FOUND` aborts the discrete-GPU power method. This Acer has **no** discrete GPU,
  so the symbol is a placeholder. **Cosmetic.**

Verdict: update the BIOS if `fwupdmgr` ever offers one; otherwise accept and move on. Do not
patch the DSDT for this.

**Failed units.** `systemctl --failed` showed four:

| Unit | Cause | Real? |
|---|---|---|
| `systemd-sysctl.service` | inline `# comment` on the value line in `/etc/sysctl.d/99-hardening.conf:11` | **yes** |
| `systemd-modules-load.service` | `acpi_call` has no module for 7.2.9 (DKMS not built) **and** Secure Boot is on (unsigned modules refused) | **yes** |
| `systemd-tpm2-setup-early.service` | TPM does not provide the NvPCR index systemd wants | cosmetic |
| `systemd-pcrproduct` / `pcrlogin@1000` | same NvPCR limitation | cosmetic |

The sysctl line is the classic trap from §5:

```
kernel.modules_disabled = 0  # Set to 1 after all modules loaded (see below)
```

The value became `0  # Set to 1 ...`, which is not an integer → `Invalid argument`. Fix: the
comment goes on its own line.

**Hardware.** `smartctl --scan` found `/dev/nvme0`; the read needs root. `rasdaemon` is not
installed, so MCEs would be invisible. Neither is currently failing — both are gaps, not faults.

**Recovery posture.** `RuntimeWatchdogUSec=0` and `kernel.panic=0`: a hang or a panic leaves the
machine dead until a human presses the button. That is the actual "self-healing" gap.

**Noise to fix separately.** `audit: backlog limit exceeded` (`audit_backlog_limit=64`, ACL
rules from hardening) needs a larger `backlog_limit` in `/etc/audit/auditd.conf`. The remaining
kernel warnings are expected here and need no action: `Tracing disabled due to lockdown` (Secure
Boot), `overlayfs: upper fs does not support file handles` (a backing filesystem without file
handles), and `pcieport … can't derive routing for PCI INT A` (a firmware PCI routing gap).
Boot takes 36.7 s, of which the kernel alone is 20.6 s — worth a `systemd-analyze
critical-chain` pass.

The `findings` and `actions` blocks in this file's frontmatter track the fixes.

---

## Gotchas

> [!warning] A firmware *bug* is not broken hardware
> `ACPI BIOS Error (bug)` means the kernel found a malformed table. Acting on it (replacing
> hardware, `acpi=off`) usually makes a working machine worse. Correlate with a real symptom
> first.

> [!warning] Inline comments break sysctl files
> `kernel.foo = 1  # reason` sets the value to `1  # reason`. `systemd-sysctl.service` fails and
> the whole file is skipped. Put every comment on its own line.

> [!warning] DKMS modules do not survive a kernel upgrade on their own
> `acpi_call-dkms` installs a `modules-load.d` entry, but if the module was not rebuilt for the
> running kernel — or Secure Boot rejects it because it is unsigned — `systemd-modules-load`
> fails at every boot. Either rebuild and sign it (MOK) or remove the request.

> [!caution] Restart loops and watchdogs both cut both ways
> `Restart=always` without `StartLimitBurst` forks forever; a watchdog timeout that is too short
> reboots a healthy but busy machine. Test both under load.

> [!danger] Do not automate `pacman -Syu`
> On a rolling release an interrupted sync is a partial upgrade. Detect with `checkupdates` and
> `arch-audit`; apply deliberately, and reboot on a kernel change.

---

## Verification

After the fixes, each finding should flip to a pass. Expected outcomes:

```bash
# 1. sysctl typo fixed → the unit starts and the value is a plain integer
sudo systemctl restart systemd-sysctl
systemctl is-failed systemd-sysctl        # -> inactive (or "active"), not "failed"
sysctl kernel.modules_disabled            # -> kernel.modules_disabled = 0

# 2. acpi_call decision made → the load unit is clean (if you kept it)
systemctl status systemd-modules-load     # -> active (exited)
lsmod | grep acpi_call                    # -> present if kept and signed

# 3. recovery posture armed
systemctl show -p RuntimeWatchdogUSec     # -> RuntimeWatchdogUSec=30s
sysctl kernel.panic                       # -> kernel.panic = 10

# 4. the whole loop, in one shot
./scripts/system-doctor.sh; echo "exit=$?" # -> fewer findings; exit is the count
```

A clean host reports only the cosmetic ACPI lines as `warn`, and exits `0` once they are the
only remaining class (they are informational in this workflow).

---

## Related

- [[arch-system-audit]] — the storage-focused sibling audit of this same host (`bacon`)
- [[Monitoring, Integrity and Auditing]] — auditd, AIDE and persistent journald, i.e. detection
- [[Arch Lifecycle — Install, Maintain, Recover]] — update hygiene, backups, rollback path
- [[kernel-dev-debugging]] — kdump, GDB and vmcore analysis when a crash needs a real post-mortem
- [[kernel-initramfs]] — the `fsck`/`resume` hooks that make boot-time repair possible
- [[systemd-and-sandboxing]] — unit hardening, `Restart=` and drop-in configuration
- [[Vault Conventions]] — frontmatter schema behind this note

## Sources

- [ACPI modules — Arch Wiki](https://wiki.archlinux.org/title/ACPI_modules) — ACPI modules, the
  `ACPI: EC: input buffer is not empty` error, and the boot-loop kernel parameters
- [DSDT — Arch Wiki](https://wiki.archlinux.org/title/DSDT) — the DSDT override procedure, as a
  last resort
- [S.M.A.R.T. — Arch Wiki](https://wiki.archlinux.org/title/S.M.A.R.T.) — `smartctl` health
  reads, self-tests, and the `smartd` daemon
- [Kdump — Arch Wiki](https://wiki.archlinux.org/title/Kdump) — `crashkernel=`, the kdump
  service, and `makedumpfile`
- [systemd-system.conf(5)](https://www.freedesktop.org/software/systemd/man/latest/systemd-system.conf.html)
  — `RuntimeWatchdogSec`, `RebootWatchdogSec`, `WatchdogDevice`
- [sysctl/kernel.rst — Linux kernel](https://docs.kernel.org/admin-guide/sysctl/kernel.html) —
  `kernel.panic`, `kernel.panic_on_oops`, `kernel.dmesg_restrict`

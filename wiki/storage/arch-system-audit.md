---
title: "Arch System Audit — LUKS + Btrfs Layout, Swap & Resize"
aliases:
  - arch system audit
  - bacon storage audit
  - LUKS btrfs audit
  - bacon
  - Arch storage audit
  - LUKS btrfs resize fix
description: >-
  Read-only audit of host `bacon` (Arch Linux, LUKS2 + btrfs, zram): current partition
  layout, proof that the 16 MiB dm-crypt offset is expected, diagnosis of the incomplete
  btrfs resize, and a runbook for adding an encrypted swapfile without repartitioning.
tags:
  - arch-linux
  - linux
  - encryption
  - luks
  - dm-crypt
  - swap
  - zram
  - btrfs
  - lvm
  - storage
  - disk-management
  - filesystem
  - audit
  - runbook
  - troubleshooting
  - self-audit
type: audit
status: needs-action
confidence: high
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2026-10-27
language: en
audience: sysadmin
scope: single host storage audit
keywords:
  - btrfs filesystem resize
  - btrfs fi usage
  - btrfs fi df
  - mkswapfile
  - subvol=@swap
  - nodatacow
  - zram-generator
  - zswap.enabled=0
  - swappiness
  - cryptdevice=
  - PARTUUID
  - dm-crypt 16 MiB header
  - btrfs cannot shrink
  - pressure stall
sources:
  - "[btrfs-progs — btrfs(5)](https://man.archlinux.org/man/btrfs.5.en.html)"
  - "[Btrfs](https://wiki.archlinux.org/title/Btrfs)"
  - "[Swap](https://wiki.archlinux.org/title/Swap)"
  - "[Power management/Suspend and hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate)"
source_retrieved: 2026-09-27
related:
  - "[[arch-encrypted-swap]]"
  - "[[Dm-crypt]]"
  - "[[Btrfs]]"
  - "[[Zram]]"
  - "[[Hibernation]]"
  - "[[system-diagnostics-and-self-healing]]"
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document system audit for LUKS and btrfs"
ai-review: pending
host: bacon
user: joaov
os: Arch Linux
kernel: 7.2.7-arch1-1
hardware: "nvme0n1, 7.53 GiB RAM, zram"
btrfs_progs: v7.1
initramfs: mkinitcpio
crypto_hook: busybox-encrypt
hibernation: false
identifiers:
  luks2_uuid: 474a4e02-b784-4947-8132-2af7a1ec1f96
  btrfs_uuid: 3940098a-3e88-4806-ac0f-cb73b157ef70
  partuuid_root: 06ec8b0c-d05e-4e11-849e-0b313460af13
  partuuid_boot: 78aaae75-40e0-45eb-a4dd-d97cc68b9e1c
  vfat_uuid_boot: 159A-5D98
  zram_swap_uuid: a06cfa34-dc14-45ff-9da9-70cec2b01c3f
findings:
  - id: incomplete-resize
    severity: high
    status: open
    fix: sudo btrfs filesystem resize max /
  - id: permissions-artifact
    severity: info
    status: resolved
    fix: use btrfs filesystem usage, or run show with sudo
actions:
  - id: resize-max
    status: pending
    command: sudo btrfs filesystem resize max /
  - id: swap-subvolume
    status: pending
    command: sudo btrfs subvolume create /@swap
  - id: swapfile
    status: pending
    command: sudo btrfs filesystem mkswapfile --size 8g --uuid clear /@swap/swapfile
  - id: fstab-entry
    status: pending
  - id: resume-hook
    status: optional
    command: add resume hook after encrypt, then mkinitcpio -P
platform:
  - Arch Linux
  - Linux
  - systemd
  - btrfs
  - LUKS
cssclasses:
  - reference
  - wide-table
---

# Arch System Audit — LUKS + Btrfs Layout, Swap & Resize

Machine-specific audit of host **`bacon`**, performed 2026-09-27. Read-only investigation — no
changes were made to the system. Companion to the generic reference: [[arch-encrypted-swap]].

> [!success] Headline
> The filesystem is **healthy**. The earlier resize failure has left one incomplete step, fixed by a
> single online `btrfs filesystem resize max /`. A separate, alarming-looking `btrfs filesystem show`
> output turned out to be a **permissions artifact, not corruption**.

---

## 1. Current layout

```
nvme0n1  238.47 GiB  (256,060,514,304 B)
├── nvme0n1p1      1.00 GiB   vfat (FAT32)  → /boot              (unencrypted)
└── nvme0n1p2    237.44 GiB   crypto_LUKS2  → /dev/mapper/root  → btrfs
                                                            ├─ @     (256) → /
                                                            ├─ @home (257) → /home
                                                            ├─ @pkg       → /var/cache/pacman/pkg
                                                            └─ @log       → /var/log
```

Classic **LUKS-on-a-partition** layout. No LVM layer, no disk swap partition, no second LUKS
container.

### Identifiers

| Thing | Value |
|---|---|
| LUKS2 container UUID | `474a4e02-b784-4947-8132-2af7a1ec1f96` |
| btrfs filesystem UUID | `3940098a-3e88-4806-ac0f-cb73b157ef70` |
| `p2` PARTUUID (root) | `06ec8b0c-d05e-4e11-849e-0b313460af13` |
| `p1` PARTUUID (boot) | `78aaae75-40e0-45eb-a4dd-d97cc68b9e1c` |
| `p1` vfat UUID | `159A-5D98` |
| zram swap UUID | `a06cfa34-dc14-45ff-9da9-70cec2b01c3f` |

### Boot & crypto configuration

Kernel command line (`/proc/cmdline`):

```
cryptdevice=PARTUUID=06ec8b0c-d05e-4e11-849e-0b313460af13:root root=/dev/mapper/root \
  zswap.enabled=0 rootflags=subvol=@ rw rootfstype=btrfs
```

`/etc/mkinitcpio.conf` → `HOOKS`:

```
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)
```

Observations:

- Uses the **busybox `encrypt` hook**, not `sd-encrypt`. Root is unlocked via `cryptdevice=` on the
  cmdline. `PARTUUID` pinning is good practice.
- **No `lvm2` hook** and `lvm2` isn't even installed — confirms no LVM anywhere.
- **No `resume` hook** — hibernation is not configured.
- `zswap.enabled=0` — zram is the sole swap mechanism.
- `/etc/crypttab` exists but is unreadable as a normal user; likely unused given `cryptdevice=`.
  Verify with `sudo cat /etc/crypttab`.

---

## 2. The false alarm — `size 0 … MISSING` is NOT corruption

Running `btrfs filesystem show` **with no argument** makes btrfs-progs *scan* `/dev` looking for
superblocks. `/dev/mapper/root` is mode `0600 root:root`, so as user `joaov` (uid 1000) it cannot
open `/dev/dm-0`. The result was:

```
	Total devices 1 FS bytes used 9.35GiB
	devid    1 size 0 used 0 path /dev/mapper/root MISSING
```

> [!warning] Do not panic
> Every authoritative measurement says the filesystem is fine:

| Check | Result | Verdict |
|---|---|---|
| `btrfs fi usage /` | Device size 237.46 GiB · **missing 0.00B** · free 226.78 GiB | healthy |
| `btrfs device stats /` | `write_io_errs 0`, `read_io_errs 0`, `corruption_errs 0`, `generation_errs 0` | healthy |
| dmesg | clean first mount, transid 97, no warnings | healthy |
| `/proc/pressure/memory` | `some 0.00` `full 0.00` | no memory pressure |
| `df -hT /` | 238G size / 11G used / 227G avail | healthy |

`btrfs filesystem usage` reads the live mount rather than scanning, which is why it is the reliable
command. **Always prefer it, or run `show` with `sudo`.**

---

## 3. The one real problem — incomplete btrfs resize

```
Data, single:   Size: 11.01GiB   Used: 8.67GiB  (78.72%)
Metadata, DUP:  Size:  1.00GiB   Used: 696.91MiB (68.06%)
System, DUP:    Size:  8.00MiB   Used: 16.00KiB (0.20%)

Overall: Allocated 13.02GiB · Unallocated 224.43GiB · Free 226.78GiB
```

An 11 GiB data chunk sitting on a 237 GiB device is the fingerprint of a filesystem that was
**created when the partition was small, then grown — with the final `btrfs filesystem resize` never
completed**.

### The LUKS layer is provably fine

| Measurement | Bytes |
|---|---|
| `nvme0n1p2` (partition) | 254,984,323,072 |
| `/dev/mapper/root` (dm-crypt) | 254,967,545,856 |
| **Difference** | **16,777,216 = exactly 16 MiB** |

A 16 MiB delta is precisely the LUKS2 header plus secondary metadata region. This proves
`cryptsetup resize` **did** run correctly against the full partition. The only step that never
happened was telling btrfs about the new space.

### Fix

A pure online grow — safe, no downtime, no data movement:

```bash
sudo btrfs filesystem resize max /
```

Growing btrfs is always safe while mounted. It is *shrinking* that btrfs cannot do.

---

## 4. Why an encrypted swap *partition* is impossible here

```
disk total      256,060,514,304
p1 + p2         256,058,064,896
unpartitioned        2,449,408   ← 2.34 MiB
```

The disk is partitioned to within 2.3 MiB of capacity. To carve out a swap partition you would have to
shrink something, and:

- **btrfs has no shrink operation** — full stop
- shrinking the LUKS2 container around a live btrfs risks total data loss

The only route would be `btrfs send` → new LUKS+LVM container → `btrfs receive`. **Not worth it for
swap alone.**

### Verdict: use a swapfile

[[arch-encrypted-swap#B1. Swap file inside the encrypted root — easiest|Swap file]] (wiki Method B1) is
the only viable option. It lives inside the existing LUKS container, so it is **encrypted by
inheritance** — no crypttab entry, no second passphrase, no repartitioning.

Your `btrfs-progs v7.1` supports `btrfs filesystem mkswapfile`, which handles the NOCOW and
preallocation requirements automatically.

---

## 5. Runbook — add encrypted swap

### Step 1 · Fix the incomplete resize first

```bash
sudo btrfs filesystem resize max /
btrfs fi df /          # Data chunk should jump to ~236 GiB
```

### Step 2 · Create the swap subvolume

```bash
sudo btrfs subvolume create /@swap
```

Created at the top level as a sibling of `@`, consistent with the existing `@` / `@home` / `@pkg` /
`@log` naming.

### Step 3 · Create and activate the swapfile

```bash
sudo btrfs filesystem mkswapfile --size 8g --uuid clear /@swap/swapfile
sudo swapon /@swap/swapfile
```

8 GiB chosen deliberately: larger than the swap priority of zram would need, and large enough to
satisfy a future hibernation image (RAM is 7.53 GiB).

### Step 4 · Make it persistent

Append to `/etc/fstab`, matching the existing style of this system:

```
UUID=3940098a-3e88-4806-ac0f-cb73b157ef70	/swap	btrfs	rw,relatime,ssd,space_cache=v2,subvol=/@swap,nodatacow	0 0
/swap/swapfile	none	swap	defaults	0	0
```

> [!caution] `nodatacow`, not `compress=zstd:3`
> The root subvolume uses `compress=zstd:3`, but a swapfile **must not be CoW, checksumed, or
> compressed**. `nodatacow` implies `nodatasum` and disables compression. The `@swap` subvolume
> **cannot be snapshotted** while the swapfile is active — not an issue here, as there is no
> snapper/timeshift configured.

### Step 5 · Verify

```bash
swapon --show
btrfs fi df /
systemctl daemon-reload
```

Expected: `dev-zram0.swap` at priority 100 (unchanged) plus the new disk swapfile at the default
priority −2. zram remains preferred; the disk swapfile acts purely as a safety valve that engages
only once zram is full.

---

## 6. Optional: hibernation

Your kernel supports it — `/sys/power/state` reports `freeze mem disk`. Currently unused, because
there is no disk-backed resume device (zram cannot survive power-off, since it is RAM).

Requirements if you want it:

- [x] Swapfile ≥ RAM size (7.53 GiB) — the 8 GiB file above covers this
- [ ] Add the **`resume` hook** to `/etc/mkinitcpio.conf`, placed **after** `encrypt`:
      `HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt resume filesystems fsck)`
- [ ] Add `resume=/dev/mapper/root` to the kernel command line
- [ ] `sudo mkinitcpio -P`

> [!danger] `/boot` is unencrypted on this machine
> The Arch Wiki explicitly warns against a keyfile-based encrypted swap when the keyfile lives in an
> unencrypted `/boot`. A swapfile *inside* the encrypted root avoids this, because root is already
> unlocked by the `encrypt` hook before `resume` runs — but verify the ordering carefully and test a
> full suspend/resume cycle before trusting it.

---

## 7. Optional: zram tuning

Current state is already sane:

| Setting | Value |
|---|---|
| RAM | 7.53 GiB (`MemTotal` 7,896,464 kB) |
| MemAvailable | 5.25 GiB |
| zram size | 3.77 GiB (50% of RAM, `zram-generator` default) |
| zram algorithm | zstd |
| Measured compression | 63,787,008 B → 15,718,651 B ≈ **4.06×** |
| zram RAM overhead | 518 MiB (`mm_stat` mem_used_total) |
| `vm.swappiness` | 60 |

`/proc/pressure/memory` reads all zeros, so no tuning is needed. If you want zram preferred even more
aggressively, `vm.swappiness=180` is the common setting for zram-only systems — purely cosmetic here.

---

## 8. Revised recommendation on LVM

Walking back part of the earlier generic advice, in light of what this audit found:

**LVM on LUKS is still the right call in general** for resize flexibility. But for *this* machine it
is **not worth the migration**:

- The single partition is already full-size — there is no resize left to protect against
- The historical resize failure is resolved by the one `resize max` in Step 1
- Gaining a swap LV would require a full `btrfs send`/`receive` migration, when a swapfile delivers
  the same encrypted swap for free

**Decision: stay on the current layout. Fix the resize, add a swapfile, done.**

---

## Diagnostic commands used

```bash
lsblk -o NAME,PATH,SIZE,TYPE,FSTYPE,FSVER,LABEL,UUID,MOUNTPOINTS
cat /etc/fstab; cat /etc/crypttab; cat /etc/mkinitcpio.conf
cat /proc/cmdline
btrfs filesystem show            # misleading as non-root — see §2
btrfs filesystem show --all-devices /
btrfs filesystem usage /
btrfs filesystem df /
btrfs device stats /
lsblk -b -o NAME,SIZE
ls -la /dev/mapper/ /dev/disk/by-uuid/ /dev/disk/by-partuuid/
cat /sys/power/state /sys/power/mem_sleep
cat /etc/systemd/zram-generator.conf
systemctl list-units --type=swap --all
grep -E "MemTotal|MemAvailable|SwapTotal" /proc/meminfo
cat /proc/pressure/memory
sysctl vm.swappiness
```

> [!note] Re-run as root for a complete picture
> Much of the above was gathered as uid 1000. For full output — `btrfs filesystem show`,
> `/etc/crypttab`, `/boot/loader/entries/*`, `sgdisk -p /dev/nvme0n1` — prefix with `sudo`.

## Sources
- [btrfs-progs — btrfs(5)](https://man.archlinux.org/man/btrfs.5.en.html) — manpage
- [Btrfs](https://wiki.archlinux.org/title/Btrfs) — wiki
- [Swap](https://wiki.archlinux.org/title/Swap) — wiki
- [Power management/Suspend and hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate) — wiki

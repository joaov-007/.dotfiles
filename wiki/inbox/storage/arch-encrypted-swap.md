---
title: "Arch Linux — Encrypted Swap & Safe Root Partition Resize"
aliases:
  - Encrypted Swap Arch
  - archwiki swap encryption
  - LUKS swap
  - Arch encrypted swap
  - btrfs swapfile
  - LUKS btrfs resize
  - cryptlvm layout
description: >-
  How to add an encrypted swap partition after an Arch install, and why resizing the root
  partition broke LUKS + btrfs. Covers random-key and hibernation-capable swap, the 1 MiB
  dummy-filesystem label trick, and the cryptlvm → vg0 layout that makes every future
  resize a non-destructive four-command operation.
tags:
  - arch-linux
  - linux
  - encryption
  - luks
  - dm-crypt
  - swap
  - btrfs
  - lvm
  - storage
  - disk-management
  - filesystem
  - hibernation
  - initramfs
  - troubleshooting
  - reference
categories: storage
type: reference
status: evergreen
confidence: high
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2027-03-27
language: en
audience: sysadmin
scope: disk encryption and swap
platform:
  - Arch Linux
  - Linux
  - systemd
  - mkinitcpio
  - busybox initramfs
keywords:
  - crypttab
  - fstab
  - mkswap
  - swapon
  - cryptsetup
  - cryptsetup resize
  - pvresize
  - lvextend
  - mkswapfile
  - hibernate=no
  - sd-encrypt
  - tpm2-device
  - offset=2048
  - LABEL=cryptswap
  - btrfs subvolume
  - NOCOW
  - zram
  - sd-boot
sources:
  - "[Dm-crypt/Swap encryption](https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption)"
  - "[Dm-crypt/Encrypting an entire system](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)"
  - "[Dm-crypt/Drive preparation](https://wiki.archlinux.org/title/Dm-crypt/Drive_preparation)"
  - "[Btrfs](https://wiki.archlinux.org/title/Btrfs)"
  - "[Swap](https://wiki.archlinux.org/title/Swap)"
  - "[Power management/Suspend and hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate)"
  - "[btrfs(5) — § SWAPFILE SUPPORT](https://man.archlinux.org/man/btrfs.5.en.html)"
  - "[cryptsetup FAQ 2.3](https://gitlab.com/cryptsetup/cryptsetup/wikis/FrequentlyAskedQuestions)"
  - "[mkinitcpio-openswap](https://aur.archlinux.org/packages/mkinitcpio-openswap/)"
source_retrieved: 2026-09-27
source_last_edited: 2026-09-13
related:
  - "[[arch-system-audit]]"
  - "[[Dm-crypt]]"
  - "[[Btrfs]]"
  - "[[LVM]]"
  - "[[Hibernation]]"
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document encrypted swap and partition resize"
ai-review: pending
cssclasses:
  - reference
---

# Arch Linux — Encrypted Swap & Safe Root Partition Resize

How to add an encrypted swap partition **after** an Arch install, and why resizing the root
partition broke LUKS + btrfs. Everything sourced from the Arch Wiki
([dm-crypt/Swap encryption](https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption),
revision `oldid=885576`, page last edited 2026-09-13).

> [!warning] The one-line summary
> Encrypting swap **is not the cause** of resize breakage. The cause is a missing **LVM layer**
> between LUKS and btrfs. Adopting `cryptlvm → vg0 → {root, swap}` makes every future resize a
> four-command, non-destructive operation. See [[#Why the resize broke LUKS + btrfs]].

---

## The two approaches at a glance

|  | Random key (no hibernation) | Persistent key (hibernation) |
|---|---|---|
| Key source | `/dev/urandom`, discarded on shutdown | Passphrase / keyfile / TPM |
| Cold-boot attack resistance | **Strong** — nothing on disk is ever readable | Swap readable while the volume is open |
| Hibernation / suspend-to-disk | No | Yes |
| Setup complexity | Low (one crypttab line) | Medium–high (initramfs work) |

**Trade-off in one sentence:** a per-boot random key gives better data protection because old
sensitive fragments swapped out long ago are never recoverable — but re-encrypting swap on each
boot generally forbids suspend-to-disk.

---

## Method A — Random key, no hibernation

The most secure option. `/etc/crypttab` decrypts the swap partition with a throwaway key at boot;
the key is gone on shutdown, leaving only inaccessible ciphertext on disk.

### 1. Plant a stable identity on the partition

A plain `LABEL=` cannot be used directly: dm-crypt and `mkswap` recreate the device every boot and
would wipe the label along with it. The workaround is a **1 MiB dummy filesystem** whose only job
is to carry a persistent UUID/LABEL that survives the wipe.

```bash
# mkfs.ext2 -L cryptswap /dev/sdX# 1M
# blkid /dev/sdX#
```

```
/dev/sdX#: LABEL="cryptswap" UUID="b72c384e-bd3c-49aa-b7a7-a28ea81a2605" TYPE="ext2"
```

The trailing `1M` limits the filesystem to 1 MiB, leaving the rest of the partition free for
encrypted swap behind it.

### 2. Add the crypttab entry

```
# <name> <device>         <password>    <options>
swap     LABEL=cryptswap  /dev/urandom  swap,offset=2048,cipher=aes-xts-plain64,size=512,sector-size=4096
```

> [!info] About `offset=2048`
> 2048 sectors × 512 bytes = **1 MiB**. It is *not* affected by the dm-crypt sector size. This skips
> over the dummy filesystem so the label/UUID survive, and the data stays properly aligned.

### 3. Add the fstab entry

```
# <filesystem>    <dir>  <type>  <options>  <dump>  <pass>
/dev/mapper/swap  none   swap    defaults   0       0
```

### 4. Result

After reboot, `swapon -s` shows an arbitrary mapper device (e.g. `/dev/dm-1`) and `lsblk` shows
**crypt** in the FSTYPE column. The UUID of `/dev/mapper/swap` **changes every boot** — that is
expected, not a bug.

### Device naming — do not skip this

> [!danger] Never use `/dev/sdX` in crypttab
> Kernel device names reorder across boots. A crypttab entry pointing at `/dev/sda3` that ends up
> on a different physical disk will **`mkswap` that disk** on next boot. This is the single most
> destructive mistake in this whole page.

Safe alternatives, in order of preference:

- `LABEL=` (via the 1 MiB dummy-fs trick above) — survives re-partitioning
- `PARTUUID=` / `PARTLABEL=` — stable, but gives no protection if you later repurpose the partition
- `by-id` / `by-path` paths — robust, but break on hardware changes
- An **LVM logical volume name** — the most robust option, and the recommended layout below

### Critical warnings from the wiki

- [!] If the partition was **previously a LUKS partition**, crypttab will *refuse* to overwrite it —
      a deliberate data-loss safeguard against misidentification. The **LUKS header must be wiped
      once** manually before the partition can be used this way.
- [!] If your kernel has `HIBERNATION` compiled in, add **`hibernate=no`** to the kernel command
      line. Otherwise the kernel probes swap for a resume image at every boot, which is useless
      with a one-time key and can hang or add boot latency.
- [!] Swap setup can occasionally fail — see [systemd issue 10179](https://github.com/systemd/systemd/issues/10179).
- [!] `Stopped (with error) /dev/dm-1` in the logs — see [systemd issue 1620](https://github.com/systemd/systemd/issues/1620).

---

## Method B — With suspend-to-disk (hibernation)

> [!note] Residual risk
> A persistent key means critical data swapped out may sit in the clear for a long time. The wiki
> suggests running a job that **re-encrypts swap on every normal shutdown** to reduce this.

### B1. Swap file inside the encrypted root — easiest

Since your root is already LUKS-encrypted, a swapfile is inherited automatically. The wiki calls
this "a very simple and flexible method... without any further setup."

```bash
# btrfs subvolume create /swap
# btrfs filesystem mkswapfile --size 8g --uuid clear /swap/swapfile
# swapon /swap/swapfile
```

```
/swap/swapfile  none  swap  defaults  0  0
```

**btrfs limitations** (from [btrfs(5)](https://man.archlinux.org/man/btrfs.5.en.html) § SWAPFILE SUPPORT):

- Single device only — not supported on multi-device filesystems
- Single data profile only
- Must be **NOCOW** (which implies NODATASUM and no compression)
- Must be pre-allocated (no holes)
- **The subvolume containing an active swapfile cannot be snapshotted** until `swapoff`

`btrfs filesystem mkswapfile` (kernel 6.1+) handles the NOCOW + preallocation requirements
automatically. Manual alternative: `truncate -s 0` → `chattr +C` → `fallocate -l 8G` → `mkswap`.

> [!tip] `resume=` must point at the unlocked device
> When using the `resume=` kernel parameter, it must reference the **mapped/unlocked** device
> containing the filesystem that holds the swapfile — not the LUKS container.

### B2. Dedicated LUKS swap partition

```bash
# swapoff /dev/device           # if currently in use
# cryptsetup luksFormat --label swap /dev/device
# cryptsetup open /dev/disk/by-label/swap swap
# mkswap /dev/mapper/swap
# swapon /dev/mapper/swap
```

```
/dev/mapper/swap none swap defaults 0 0
```

Kernel cmdline: `resume=/dev/mapper/swap`

> [!warning] Do not use this with a keyfile in an unencrypted `/boot`
> The wiki explicitly warns against this combination — the key would be readable at boot.

**Unlocking it early (required for resume).** With the systemd-based initramfs and the `sd-encrypt`
hook, either pass `rd.luks.uuid=` on the kernel cmdline or add to `/etc/crypttab` and regenerate the
initramfs:

```
swap UUID=56f8ee97-54b3-4a65-9282-688deb922527 none x-initrd.attach,tpm2-device=auto
```

With the busybox `encrypt` hook you must hand-write a hook — that hook can only unlock a *single*
device, and the swap partition on a different disk will not be opened automatically. Either
install the [`mkinitcpio-openswap`](https://aur.archlinux.org/packages/mkinitcpio-openswap/) AUR
package or create `/etc/initcpio/hooks/openswap` by hand, then:

```
HOOKS=(... encrypt openswap resume filesystems ...)
```

With a keyfile stored on the encrypted root, mount `-o ro,noload` to read it — and adjust those
options for anything other than ext4.

### B3. TPM (unattended decryption)

```bash
# systemd-cryptenroll --tpm2-device auto /dev/device
# systemd-cryptenroll --wipe-slot password /dev/device
# systemd-cryptenroll /dev/device
```

```
SLOT TYPE
   0 tpm2
```

Wiping the password slot means the swap volume opens with no prompt — convenient, but understand
you are trusting the TPM binding alone.

### B4. LVM on LUKS — simplest for hibernation

> "If the swap volume is in a volume group that gets activated in initramfs, simply follow the
> instructions in [Hibernation]."

No second crypttab entry, no second passphrase, no custom initramfs hook. See the layout below.

---

## Why the resize broke LUKS + btrfs

> [!important] Root cause
> The swap setup is a red herring. The damage came from resizing a **plain `LUKS → btrfs` layout
> with no LVM in between**, which requires manipulating the LUKS mapping itself — the step most
> likely to go wrong.

### btrfs cannot shrink

There is **no** shrink operation for btrfs. `btrfs filesystem resize` only grows. If any shrink was
attempted, that alone explains the filesystem damage — recovery means backup plus
`btrfs send`/`receive`, not `resize`.

### Growing without LVM — the three failure modes

**1. The partition's start offset moved.** LUKS2 keeps metadata at **both ends** of the device. Any
partition-table edit that shifts the *beginning* of the encrypted partition — inserting a new swap
partition *before* it, or a tool that rewrites the whole table — misaligns everything and corrupts
the mapping. **Always append new partitions after existing ones.**

**2. `cryptsetup resize` missing or misapplied.** Growing the partition does nothing on its own; the
dm-crypt mapping retains its old size. Omitting it yields `ENOSPC` / "device busy". Running it
against a mounted btrfs is what produces actual corruption.

**3. Resizing from the live system.** Do this from the install ISO instead. See the safety note
below.

### The correct grow sequence (no LVM)

Run from a live ISO, unlocking root **before** touching the partition table:

```bash
# cryptsetup open /dev/nvme0n1p3 cryptroot
# sgdisk -s +100% /dev/nvme0n1      # or: parted resizepart 3 100%
# partprobe /dev/nvme0n1
# cryptsetup resize /dev/mapper/cryptroot
# mount /dev/mapper/cryptroot /mnt
# btrfs filesystem resize max /mnt
```

> [!danger] Shrinking is not an option
> btrfs has no shrink. To reclaim space you must back up (`btrfs send`) into a new, smaller
> filesystem and `btrfs receive` it back. Plan disk layout accordingly — this is the other reason
> to prefer LVM.

---

## The fix — LVM on LUKS

One container, one passphrase, swap carved from leftover space:

```
nvme0n1
├── p1  /boot (unencrypted, unavoidable)
└── p3  cryptlvm (LUKS2)
        └── vg0
            ├── root  (btrfs)
            └── swap
```

Resizing forever after becomes four non-destructive commands, with **no `cryptsetup resize`**:

```bash
# sgdisk -s +100% /dev/nvme0n1 && partprobe /dev/nvme0n1
# pvresize /dev/nvme0n1p3
# lvextend -l +100%FREE /dev/vg0/root
# btrfs filesystem resize max /
```

And swap stops being a special case — it is a normal LV unlocked by the single root passphrase at
boot, with no extra crypttab entry and no hand-written initramfs hook.

> [!note] Migration cost
> You cannot insert LVM under an existing LUKS volume non-destructively. Migrating an existing
> install means backing up with `btrfs send`, creating a new LUKS+LVM container, and restoring.
> Only worth it if you expect to keep resizing — otherwise Method A or B1 is fine.

---

## Quick reference

| Task | Command |
|---|---|
| Verify swap is active | `swapon -s` / `cat /proc/swaps` |
| See the encryption stack | `lsblk -f` (FSTYPE shows `crypt`) |
| Rebuild initramfs after crypttab change | `mkinitcpio -P` |
| Reload systemd units | `systemctl daemon-reload` |
| Find the real device behind a path | `find -L /dev/disk -samefile /dev/sdaX` |
| Grow a physical partition | `sgdisk -s +100% /dev/nvme0n1 && partprobe /dev/nvme0n1` |
| Tell LVM the PV grew | `pvresize /dev/nvme0n1p3` |
| Grow an LV | `lvextend -l +100%FREE /dev/vg0/root` |
| Grow btrfs to fill | `btrfs filesystem resize max /` |
| Check filesystem usage | `btrfs fi df /` |
| Find swapfile's resume offset | `btrfs inspect-internal map-swapfile -r /swap/swapfile` |

## Related notes

- [[arch-system-audit]] — this vault's host `bacon`: actual layout, the incomplete-resize
  diagnosis, and the swapfile runbook for a full-disk LUKS + btrfs install

## Sources
- [dm-crypt/Swap encryption](https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption) — primary
- [dm-crypt/Encrypting an entire system](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system) — LVM on LUKS
- [dm-crypt/Drive preparation](https://wiki.archlinux.org/title/Dm-crypt/Drive_preparation) — wiping LUKS headers
- [Btrfs](https://wiki.archlinux.org/title/Btrfs) — swap file section
- [Swap](https://wiki.archlinux.org/title/Swap)
- [btrfs(5)](https://man.archlinux.org/man/btrfs.5.en.html) — § SWAPFILE SUPPORT
- [Power management/Suspend and hibernate](https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate)
- [cryptsetup FAQ 2.3](https://gitlab.com/cryptsetup/cryptsetup/wikis/FrequentlyAskedQuestions#2-setup)

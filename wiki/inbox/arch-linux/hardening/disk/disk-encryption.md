---
title: "Disk Encryption"
aliases:
  - Disk Encryption
  - disk encryption
  - full disk encryption
  - LUKS2
  - LVM on LUKS
  - encrypted swap
  - TPM2 unlock
  - FIDO2 unlock
description: >-
  LUKS2 full-disk encryption on Arch: the LVM-on-LUKS layout, mkinitcpio hooks, systemd
  enrollement for TPM2 and FIDO2 unlock, and encrypted swap — plus why the swap path is the
  one that silently leaks memory to disk.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - encryption
  - luks
  - dm-crypt
  - lvm
  - swap
  - zram
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
  Encryption of data at rest on a single Arch host: LUKS2 container, LVM layout, swap, and
  systemd-cryptenroll unlock factors. Does not cover remote/LUKS key servers or detached-header
  operational details.
platform:
  - arch-linux
  - systemd
  - initramfs
keywords:
  - cryptsetup luksFormat
  - LUKS2
  - aes-xts-plain64
  - sd-encrypt
  - mkinitcpio hooks
  - systemd-cryptenroll
  - TPM2 PCR 7
  - FIDO2 systemd-cryptenroll
  - crypttab
  - zram-generator
  - recovery key
related:
  - "[[Boot and Secure Boot]]"
  - "[[Arch Lifecycle — Install, Maintain, Recover]]"
  - "[[Filesystem and Physical Security]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Disk Encryption

> [!summary] One-paragraph answer
> Full-disk encryption is the **only** control that protects data from someone holding the
> physical disk. On Arch the modern layout is LUKS2 + LVM + btrfs, unlocked through the
> `sd-encrypt` initramfs hook (systemd), with TPM2 or FIDO2 as an additional unlock factor once
> Secure Boot is in place. Encrypt swap too — an unencrypted swap partition is the most common
> way memory contents survive a power-off on an otherwise encrypted laptop.

## Context

Open this before installing, or when adding a TPM/FIDO2 unlock factor to an existing LUKS2
container. Two facts drive every decision here:

1. Encryption is applied **after** partitioning and **before** filesystem creation. If you did
   not encrypt at install time, encrypting later means backing up, wiping and reinstalling.
2. `cryptsetup` does **not** enable authenticated (integrity) encryption by default. Without
   `--integrity`, an attacker with physical access can still *corrupt* ciphertext even though
   they cannot read it.

## Details

### 1. The LVM-on-LUKS layout

```bash
# ESP: FAT32, 512M–1G;  LUKS2: the rest
mkfs.vfat -F 32 /dev/sdX1

cryptsetup luksFormat --type luks2 \
  --cipher aes-xts-plain64 --key-size 512 \
  --hash sha512 --iter-time 5000 --use-urandom \
  /dev/sdX2

cryptsetup open /dev/sdX2 cryptlvm
pvcreate /dev/mapper/cryptlvm
vgcreate vg0 /dev/mapper/cryptlvm
lvcreate -L 32G -n swap vg0
lvcreate -l 100%FREE -n root vg0

mkfs.btrfs /dev/vg0/root
mkswap /dev/vg0/swap
```

Add an integrity layer with `--integrity hmac-sha256` if you accept the space and performance
cost; it turns silent ciphertext tampering into a hard read error.

### 2. initramfs hooks

`/etc/mkinitcpio.conf` — the systemd-based unlock path:

```bash
HOOKS=(base systemd autodetect microcode modconf kms keyboard \
       sd-vconsole sd-encrypt block filesystems fsck)
```

```bash
sudo mkinitcpio -P
```

> [!info] `sd-encrypt` vs `encrypt`
> `sd-encrypt` is the systemd path and is what supports TPM2/FIDO2 enrollement and
> `crypttab.initramfs`. `encrypt` is the busybox path and does not. Pick one and keep it.

### 3. Add unlock factors with `systemd-cryptenroll`

Always create a **recovery key first** — a TPM that loses its PCR state locks you out otherwise:

```bash
# recovery key (store it offline, not on this machine)
systemd-cryptenroll /dev/sdX2 --recovery-key

# TPM2, bound to the Secure Boot state (PCR 7)
systemd-cryptenroll /dev/sdX2 \
  --tpm2-device=auto --tpm2-pcrs=7 --tpm2-with-pin=yes
```

> [!warning] PCR 7 is tied to Secure Boot state
> Changing Secure Boot keys, updating the firmware database, or disabling Secure Boot will change
> PCR 7 and invalidate the TPM keyslot. That is the intended tamper evidence — it is also why
> the recovery key must exist before you enrol the TPM.

FIDO2 hardware key (a genuine second factor, not just convenience):

```bash
pacman -S libfido2
systemd-cryptenroll --fido2-device=auto /dev/sdX2
echo 'cryptroot /dev/sdX2 none fido2-device=auto' | sudo tee -a /etc/crypttab.initramfs
```

### 4. Encrypted swap

**Never** run unencrypted swap — the kernel writes pages of memory, including key material, to
it. Two acceptable options:

```ini
# /etc/crypttab — random key per boot, no passphrase prompt
swap /dev/sdX3 /dev/urandom swap,offset=2048,cipher=aes-xts-plain64,size=256
```

```ini
# /etc/systemd/zram-generator.conf — compressed RAM without touching disk
[zram0]
zram-size = ram / 2
compression-algorithm = zstd
swap-priority = 100
fs-type = swap
```

zram avoids disk entirely and is the better default on a machine with RAM to spare; an encrypted
disk-backed swap file is the choice when you need hibernation.

### 5. The full chain

```
UEFI Secure Boot → signed bootloader → signed UKI → TPM2 releases LUKS key → LUKS2 root
```

Each arrow is a separate note's job: the boot chain is [[Boot and Secure Boot]], the container is
here, and the swap layout details live with [[Filesystem and Physical Security]].

## Gotchas

> [!danger] No recovery key before TPM enrolment
> A firmware update or a Secure Boot key change moves PCR 7 and the TPM keyslot stops working.
> Without an independent recovery key or passphrase keyslot, the data is gone.

> [!warning] `--use-urandom` vs `--use-random`
> For a keyfile or a headless wipe this matters; for interactive `luksFormat` the entropy is
> fine either way. What actually matters is a **strong passphrase** and a **high `--iter-time`**.

> [!caution] Encrypting swap breaks hibernation unless it is configured
> Hibernation needs a persistent, known swap device and matching `resume=` parameters. A
> `--recovery-key`-style random-key swap cannot resume. If you hibernate, use an encrypted swap
> file with a persistent key, not `/dev/urandom`.

> [!warning] LUKS2 default PBKDF can be slow to unlock
> LUKS2 uses Argon2id by default. On very slow machines, a long `--iter-time` is a multi-second
> unlock. This is a deliberate cost; do not lower it without understanding the threat model.

## Verification

```bash
sudo cryptsetup luksDump /dev/sdX2 | grep -iE 'Version|Keyslots|Tokens'
# expect LUKS2, a passphrase/recovery slot, and a systemd-tpm2 token if enrolled

lsblk -f                       # root sits on a luks/crypt device, swap is crypt or zram
swapon --show                  # shows /dev/zram0 or /dev/mapper/... not a bare partition
cat /proc/cmdline | grep -o 'rd.luks[^ ]*'   # the sd-encrypt unlock parameters
```

After a reboot the system should prompt once (passphrase) or unlock silently (TPM + PIN) and
`swapon --show` should list only encrypted/zram devices.

## Related

- [[Boot and Secure Boot]] — the layer that makes TPM unlock meaningful
- [[Filesystem and Physical Security]] — mount options and USB/physical controls
- [[Arch Lifecycle — Install, Maintain, Recover]] — recovery keys and offline backup discipline

## Sources

- [Dm-crypt/Encrypting an entire system — ArchWiki](https://wiki.archlinux.org/title/Dm-crypt/Encrypting_an_entire_system)
  — LVM-on-LUKS layout, LUKS2 formatting
- [Dm-crypt/Swap encryption — ArchWiki](https://wiki.archlinux.org/title/Dm-crypt/Swap_encryption)
  — the `/dev/urandom` crypttab line and hibernation caveats
- [systemd-cryptenroll(1)](https://man.archlinux.org/man/systemd-cryptenroll.1.en) — TPM2 and
  FIDO2 enrolment, PCR selection, recovery keys
- [PrivSec — Desktop Linux Hardening](https://privsec.dev/posts/linux/desktop-linux-hardening/)
  — `--integrity`, encrypted swap, the TPM PCR-registry clip

---
title: "Boot and Secure Boot"
aliases:
  - Boot and Secure Boot
  - boot hardening
  - secure boot
  - sbctl
  - unified kernel image
  - UKI
  - kernel command line
  - Secure Boot Setup Mode
  - sbctl runbook
description: >-
  Hardening the pre-OS chain on Arch: systemd-boot and Unified Kernel Images, plus a
  copy-pasteable runbook for putting the firmware into Secure Boot Setup Mode (including the
  Acer Aspire A315-58 / InsydeH2O path), enrolling your own keys with sbctl, signing the UKI
  and bootloader, and letting the sbctl pacman hook re-sign the chain after every update.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - boot
  - secure-boot
  - uefi
  - tpm
  - kernel
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-11
last_reviewed: 2026-10-11
review_after: 2027-04-11
language: en
audience: sysadmin
scope: >-
  The systemd-boot / UKI / Secure Boot (sbctl) chain — Setup Mode entry, key creation and
  enrollment, signing and automatic re-signing, kernel command-line hardening — on a single
  UEFI Arch host. Includes the Acer Aspire A315-58 (InsydeH2O) firmware path. Does not cover
  GRUB specifics or shim/MOK for third-party kernels and Windows dual-boot.
platform:
  - arch-linux
  - systemd
  - uefi
  - insydeh2o
keywords:
  - systemd-boot
  - sbctl create-keys
  - sbctl enroll-keys -m -f
  - sbctl sign -s
  - sbctl sign-all
  - sbctl verify
  - zz-sbctl.hook
  - mkinitcpio
  - ukify
  - /etc/kernel/cmdline
  - Setup Mode
  - Erase all Secure Boot Settings
  - InsydeH2O
  - Acer Aspire A315-58
  - dbDefault KEKDefault
  - efi-readvar
  - sbverify
  - lockdown
  - module.sig_enforce
  - editor no
source_retrieved: 2026-10-11
related:
  - "[[Disk Encryption]]"
  - "[[Kernel Hardening]]"
  - "[[Arch Linux Security Hardening]]"
  - "[[firmware-update-bricks]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Expand into a full sbctl Setup Mode + automatic-signing runbook with the Acer Aspire A315-58 (InsydeH2O) firmware path and a profile of the reference host"
ai-review: pending
---

# Boot and Secure Boot

> [!summary] One-paragraph answer
> Everything before the kernel runs is attack surface. Boot with a **small** bootloader
> (`systemd-boot`), pack kernel + initramfs + command line into a **Unified Kernel Image**, sign
> it and the bootloader, then enforce that signature with **Secure Boot using your own keys**
> (`sbctl`). The step that actually blocks people is getting the firmware into **Setup Mode** —
> on Acer/InsydeH2O you must set a supervisor password and choose *Erase all Secure Boot
> Settings*, which deletes the Platform Key. After enrollment, the `zz-sbctl.hook` pacman hook
> re-signs the whole chain automatically on every kernel or systemd update.

## Context

Open this when you have UEFI firmware and want to close the "evil maid"/boot-tampering threat,
or when you set up TPM disk unlock, which depends on Secure Boot state. The key idea: a password
prompt and an initramfs are only trustworthy if the thing that ran them was itself verified.

This note is also the **runbook** for the reference host below. Generic instructions work
anywhere; the Acer path in step 4 is what this hardware needs and is the part most guides omit.

### Reference system (this machine)

Collected 2026-10-11. Report facts from here whenever the runbook says "this host".

| Item | Value |
|---|---|
| Vendor / model | Acer **Aspire A315-58** (board `Camellia_TL`, system version V1.35) |
| Firmware | **InsydeH2O** `V1.35`, dated 2023-07-10; UEFI 2.70 (INSYDE Corp. 28689.309) |
| CPU | 11th Gen Intel Core **i3-1115G4** (Tiger Lake) |
| TPM | `INTC6000` via `tpm_crb_acpi` (Intel PTT firmware TPM), device `/dev/tpmrm0` |
| Disk | `IM2P33F8ABR2-256GB` NVMe (`/dev/nvme0n1`) |
| ESP | `nvme0n1p1`, FAT32, mounted `/boot` (`fmask=0077,dmask=0077` → `/boot` is mode 700) |
| Root | `nvme0n1p2` LUKS2 → btrfs (`subvol=@`); swap is `zram0` |
| Bootloader | `systemd-boot` 262-1, `\EFI\systemd\systemd-bootx64.efi` (Boot0003 "Linux Boot Manager") |
| Kernel image | one UKI: `/boot/EFI/Linux/arch-linux.efi` (systemd-stub; no separate initramfs) |
| UKI build | mkinitcpio 42.2 (uses `ukify` when present, otherwise `objcopy` — `ukify` is absent here) |
| Secure Boot | **disabled**; **Setup Mode: disabled**; `sbctl`: not configured (`/var/lib/sbctl` absent) |
| Vendor keys | `microsoft`, plus firmware `builtin-db` ×4, `builtin-KEK`, `builtin-PK` |
| Automation | `zz-sbctl.hook` present (`sbctl sign-all -g`); `systemd-boot-update.service` **disabled** |

## Details

### 1. Bootloader choice

| Bootloader | Security | Notes |
|---|---|---|
| **systemd-boot** | small attack surface, native UKI | recommended for hardened systems (this host) |
| GRUB | feature-rich, larger surface | needs its own password for boot-menu security |
| rEFInd | good UKI support | moderate surface |

### 2. Unified Kernel Image (UKI)

A UKI is one signed EFI binary containing kernel + initramfs + command line + microcode. There is
no separate initramfs to tamper with, which closes the classic Secure Boot gap.

This host already produces a UKI from the mkinitcpio preset — there is nothing to change:

```ini
# /etc/mkinitcpio.d/linux.preset
PRESETS=('default')
default_uki="/boot/EFI/Linux/arch-linux.efi"
default_options="--splash /usr/share/systemd/bootctl/splash-arch.bmp"
# fallback is commented out — only sign the fallback line if you enable it
```

Rebuild after any change:

```bash
sudo mkinitcpio -P
```

mkinitcpio signs nothing itself; step 7 (or the pacman hook) does that. On hosts without a UKI
yet, set `default_uki=`/`fallback_uki=` in the preset and rebuild.

### 3. The key hierarchy (why Setup Mode exists)

Secure Boot stores four EFI variables:

| Variable | Holds | Role |
|---|---|---|
| **PK** (Platform Key) | one key only | owner of the platform; its presence = **User Mode** |
| **KEK** (Key Exchange Key) | one or more keys | authorises updates to `db`/`dbx` |
| **db** (signature database) | keys/hashes | binaries allowed to run |
| **dbx** (forbidden signatures) | keys/hashes | binaries explicitly blocked |

The firmware is in **Setup Mode** exactly when **PK is absent**. Until you re-enroll a PK, the
firmware accepts new key material. That is the whole trick: you are not "unlocking" anything, you
are deleting the PK so the platform has no owner. `sbctl enroll-keys` then writes your PK (User
Mode), KEK and db.

> [!important] Acer/InsydeH2O does not expose a plain "clear PK" button
> It hides key management behind `Secure Boot Mode: Custom`, and the actual delete is a menu
> item called **Erase all Secure Boot Settings**. See step 4.

### 4. Put the firmware into Setup Mode

You must do this **before** `sbctl enroll-keys`; enrolling from User Mode is rejected by the
firmware.

#### 4.1 This host — Acer Aspire A315-58 (InsydeH2O)

1. Reboot into firmware setup: power on and tap **F2** repeatedly, or from Linux run
   `sudo systemctl reboot --firmware-setup`.
2. Go to the **Security** tab and set a **Supervisor Password**. On Acer InsydeH2O the Secure
   Boot controls are greyed out until a supervisor password exists. Record the password — losing
   it locks you out of firmware settings.
3. **F10** to save and exit, then re-enter the BIOS with **F2** (the Secure Boot controls appear
   only on the next entry).
4. On the **Security** tab, open **Secure Boot** and set:
   - **Secure Boot: Enabled**
   - **Secure Boot Mode: Custom** — Custom is the mode that allows user-managed keys.
5. Select **Erase all Secure Boot Settings** (may also read *Delete all Secure Boot variables* or
   *Erase all Secure Boot settings*) and confirm. This removes the PK and drops the firmware into
   **Setup Mode**.
6. **F10** to save and exit, boot back into Arch.
7. Confirm:

   ```bash
   sudo sbctl status
   ```

   `Setup Mode` must now read **enabled**. If it still says *disabled*, see the gotchas.

Leave **Secure Boot: Enabled** and **Secure Boot Mode: Custom**. Do not switch the mode back to
`Standard` after step 5 — that can reinstall the factory key set and undo Setup Mode.

#### 4.2 Other firmwares (if you repeat this elsewhere)

The principle is identical: enter firmware setup and delete/clear the certificates (at minimum the
PK) while leaving Secure Boot enabled, then reboot. Framework exposes *Erase all Secure Boot
Settings*; many Dell/Lenovo models require setting an admin password first, and some only unlock
the option after toggling Secure Boot off and on.

### 5. Back up the vendor keys first

Wipe = irreversible. Save the current variables to **encrypted** storage (never the ESP) so you
can audit or restore them:

```bash
sudo pacman -S efitools sbsigntools
sudo mkdir -p /root/secureboot-backup && cd /root/secureboot-backup
for var in PK KEK db dbx; do sudo efi-readvar -v "$var" -o "old_${var}.esl"; done
sudo sbctl list-enrolled-keys
```

`dbx` (the revocation list) is worth keeping: `Erase all Secure Boot Settings` clears it too, and
`sbctl` does not manage `dbx`. Restoring it is an advanced, optional step (via `sbkeysync` with
the `.esl` you just saved); most desktop users accept the empty `dbx` in exchange for owning the
platform.

### 6. Create and enroll your keys

```bash
sudo sbctl create-keys                      # -> /var/lib/sbctl/keys/{PK,KEK,db}
sudo sbctl create-keys --export /root/secureboot-backup/keys   # keep an offline copy
sudo sbctl enroll-keys -m -f                # Microsoft + firmware-builtin certs
```

- `-m` / `--microsoft` appends Microsoft's certificates to `db`. **Keep this on this host.** The
  Acer firmware and the Intel Option ROMs are signed with Microsoft/OEM certs; without them a
  firmware update or an OpROM can fail to validate and, on bad firmware, brick the machine.
- `-f` / `--firmware-builtin` appends the machine's own `dbDefault`/`KEKDefault` entries (this
  host has them). Together `-m -f` is the conservative choice.
- Enrolling the PK is what flips the platform from Setup Mode to **User Mode**.

```bash
sudo sbctl status
```

Expect `Setup Mode: disabled` and `Secure Boot: disabled` (still off until you re-enable it in the
firmware *after* signing). Do **not** reboot into the firmware yet — sign first.

> [!danger] Dropping `-m` is not free
> Firmware and Option ROMs on many machines are validated with Microsoft/OEM keys. Enrolling only
> your own keys can block firmware updates, stop other boot entries, and on non-compliant firmware
> brick the device. Research your exact model before dropping `-m`.

### 7. Sign the boot chain

Find the ESP and list what is unsigned:

```bash
findmnt /boot            # this host: nvme0n1p1 mounted at /boot
sudo sbctl verify        # lists every boot-relevant EFI binary and its signature state
```

Sign each file and **save it in sbctl's database** (`-s` / `--save`) so the hook re-signs it
later. This host's exact set:

```bash
# the UKI the firmware chain loads (through systemd-boot)
sudo sbctl sign -s /boot/EFI/Linux/arch-linux.efi

# sign the fallback UKI only if you re-enable the fallback preset
# sudo sbctl sign -s /boot/EFI/Linux/arch-linux-fallback.efi

# systemd-boot as copied onto the ESP
sudo sbctl sign -s /boot/EFI/systemd/systemd-bootx64.efi

# and its master copy in /usr/lib, so bootctl install/update prefers the signed file
sudo sbctl sign -s -o /usr/lib/systemd/boot/efi/systemd-bootx64.efi.signed \
  /usr/lib/systemd/boot/efi/systemd-bootx64.efi
```

If you also keep a `\EFI\BOOT\BOOTX64.EFI` fallback path, sign that too. Same for third-party
binaries you actually use (`memtest86+-efi`, `edk2-shell`, rEFInd, …).

```bash
sudo sbctl verify        # every listed file should now read "is signed"
```

Then reboot into the firmware, keep **Secure Boot enabled**, boot normally, and confirm:

```bash
sudo sbctl status        # Secure Boot: enabled (user)
```

### 8. Automatic signing (the whole point)

`sbctl` ships a pacman hook. On this host it lives at `/usr/share/libalpm/hooks/zz-sbctl.hook` and
fires after any transaction touching these paths:

```ini
[Trigger]
Type = Path
Operation = Install
Operation = Upgrade
Operation = Remove
Target = boot/*
Target = efi/*
Target = usr/lib/modules/*/vmlinuz
Target = usr/lib/modules/*/extramodules/*
Target = usr/lib/**/efi/*.efi*
Target = usr/share/**/*.efi*

[Action]
Description = Signing EFI binaries...
When = PostTransaction
Exec = /usr/bin/sbctl sign-all -g
```

So the maintenance loop is automatic: a kernel upgrade rebuilds the UKI via mkinitcpio, and
`sbctl sign-all -g` re-signs every saved path — UKI and bootloader included. You normally do
nothing.

Useful manual commands:

```bash
sudo sbctl list-files      # everything currently saved for re-signing
sudo sbctl sign-all        # force a re-sign pass (e.g. after a manual change)
sudo sbctl remove-file /path   # stop tracking a file
```

Two caveats specific to this setup:

- **systemd-boot is not auto-copied to the ESP** (`systemd-boot-update.service` is disabled here).
  After a `systemd` upgrade run `sudo bootctl update`, then `sudo sbctl sign-all` — `bootctl` is
  not a pacman transaction, so the hook does not fire for the copy it writes. Signing the
  `/usr/lib/.../*.efi.signed` file (step 7) means `bootctl` copies the already-signed file in the
  first place.
- **mkinitcpio needs no ukify here.** mkinitcpio 42.2 builds the UKI with `objcopy` when `ukify`
  is absent; the result is a normal PE binary that `sbctl` signs the same way. Nothing to install.

### 9. Kernel command line

`/etc/kernel/cmdline` is embedded into the UKI, so it cannot be edited at the boot menu. This host
already carries the structural parameters:

```
cryptdevice=PARTUUID=<...>:root root=/dev/mapper/root rw rootflags=subvol=@ rootfstype=btrfs
quiet loglevel=3

slab_nomerge page_alloc.shuffle=1 init_on_alloc=1 init_on_free=1 pti=on random.trust_cpu=off

lockdown=confidentiality module.sig_enforce=1
```

`lockdown=confidentiality` and `module.sig_enforce=1` are the structural block against unsigned
kernel modules (see [[Kernel Hardening]]). Signing the UKI is what makes *these* parameters
tamper-evident.

### 10. Lock the boot directory and the boot menu

```bash
sudo chmod 700 /boot      # already provided by the fmask=0077 ESP mount option on this host
```

```ini
# /boot/loader/loader.conf — confirm the entry id with: bootctl list
default arch-linux.efi
timeout 3
console-mode max
editor no
```

`editor no` stops anyone at the machine from editing kernel parameters (e.g. adding `single` or
`init=/bin/sh`) at the boot menu.

## Gotchas

> [!warning] `Setup Mode` did not stick on the Acer
> Sequence matters on InsydeH2O: set the supervisor password, save, reboot, then set
> `Secure Boot Mode: Custom` and *Erase all Secure Boot Settings*. If the erase appears to do
> nothing, try, in order: (1) erase while Secure Boot is **disabled**, save & exit, re-enter, and
> re-enable Secure Boot — some builds only commit the PK deletion on a state toggle; (2) toggle
> `Custom → Standard → Custom` and erase again. Verify with `sudo sbctl status` after each attempt,
> not from within the BIOS screen.

> [!warning] `module.sig_enforce=1` before the modules are signed
> With Secure Boot on and the kernel enforcing signatures, every module must be signed with a
> trusted key. Arch's own modules qualify; out-of-tree modules (NVIDIA, VirtualBox, some ZFS
> builds) will refuse to load until signed with a key the kernel trusts. Test before making it
> permanent.

> [!danger] Bricking risk on key replacement
> Enrolling only your own keys, or clearing the vendor `db`, can leave the firmware and OpROMs
> unverifiable. Always keep `-m -f`, back up `PK/KEK/db/dbx` (step 5), and keep a supervisor
> password and a recovery USB documented.

> [!caution] Secure Boot is not a verified boot process
> It verifies the *firmware-to-kernel* chain. It does not measure the whole OS the way
> Android/ChromeOS verified boot does. Treat it as one strong layer, not a solved problem.

> [!warning] A changed PCR after a firmware update
> Enrolling TPM unlock against PCR 7 means a firmware or key change invalidates the keyslot. The
> recovery key (see [[Disk Encryption]]) is not optional.

> [!caution] `sbctl enroll-keys -f` enrols the *current* built-in key set
> The `-f` flag pulls what the firmware currently reports as `dbDefault`/`KEKDefault`; confirm
> that is what you want before running it. `--yes-this-might-brick-my-machine` overrides the
> Option ROM safety check — do not use it without understanding the risk.

## Verification

```bash
sudo sbctl status        # Installed ✓, Setup Mode disabled, Secure Boot: enabled (user)
sudo sbctl verify        # every boot-relevant file: "is signed"
bootctl status           # Firmware / Secure Boot: enabled (user) / TPM2 Support: yes
cat /proc/cmdline        # lockdown= and module.sig_enforce= present
sbverify --list /boot/EFI/Linux/arch-linux.efi   # shows your db certificate
```

`bootctl status` should show `Secure Boot: enabled (user)` and `TPM2 Support: yes`; `sbctl verify`
should list **no** missing signatures. After a `pacman -Syu` that bumps the kernel, re-run
`sbctl verify` — the hook should have re-signed everything without intervention.

## Rollback and recovery

- **Won't boot after enabling Secure Boot:** re-enter firmware (F2), set `Secure Boot Mode:
  Standard` or use *Restore Secure Boot to Factory Settings*, or simply disable Secure Boot, to get
  back in. Then redo steps 4–7.
- **Return the platform to Setup Mode from a running system:**
  ```bash
  sudo sbctl reset        # deletes the PK, platform back to Setup Mode
  ```
- **Restore the original vendor keys:** re-enroll the saved `old_PK.esl` / `old_KEK.esl` /
  `old_db.esl` with `sbkeysync` (or from a `Custom`-mode firmware menu). Keep the files offline.
- **No boot at all:** boot an Arch ISO — with Secure Boot temporarily disabled in the firmware —
  and re-sign or reset from there.

## Related

- [[Disk Encryption]] — TPM2 unlock is bound to the Secure Boot state configured here
- [[Kernel Hardening]] — the runtime half of what the command line enforces
- [[Arch Linux Security Hardening]] — where this sits in the whole picture

## Sources

- [Unified Extensible Firmware Interface/Secure Boot — ArchWiki](https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot)
  — key hierarchy, Setup Mode, sbctl workflow, pacman hook, Microsoft/OEM key caveat
- [sbctl(8) — Arch manual pages](https://man.archlinux.org/man/sbctl.8)
  — `create-keys`, `enroll-keys -m -f`, `sign -s -o`, `sign-all`, `reset`, Option ROM note
- [sbctl — Foxboron](https://github.com/Foxboron/sbctl) — behavior of `enroll-keys` and the hook
- [Unified kernel image — ArchWiki](https://wiki.archlinux.org/title/Unified_kernel_image)
  — mkinitcpio/ukify UKI layout and signing
- [How to put Secure Boot into Setup Mode (Aspire/Nitro, InsydeH2O)](https://community.acer.com/en/discussion/703972/nitro-an515-57-how-to-put-secure-boot-into-setup-mode-platform-keys-arent-being-cleared)
  — supervisor password then step-by-step BIOS changes; the Acer path in step 4.1
- [Acer BIOS setup without deleting Microsoft keys — r/archlinux](https://www.reddit.com/r/archlinux/comments/1o5njpr/acer_bios_setup_without_deleting_microsoft_keys/)
  — confirms Acer requires clearing *all* keys (including Microsoft) to reach Setup Mode

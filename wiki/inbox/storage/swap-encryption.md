---
title: "Swap encryption — usually you already have it"
description: "Why a swapfile inside a LUKS2 root needs no extra encryption, and when a separately encrypted swap partition is actually required."
tags:
  - linux
  - arch
  - luks
  - swap
  - btrfs
  - zram
  - storage
  - security
categories: storage
type: reference
status: draft
created: 2026-09-26
updated: 2026-10-12
related:
  - arch-setup
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document swap encryption on LUKS"
ai-review: pending
language: en
audience: sysadmin
scope: encrypting swap on Linux
keywords:
  - swap
  - encryption
  - dm-crypt
  - hibernation
  - systemd
platform:
  - Linux
  - systemd
cssclasses:
  - reference
last_reviewed: 2026-10-12
review_after: 2027-01-12
---

# Swap encryption — usually you already have it

Swap is the only part of a running Linux system that deliberately writes the
contents of RAM to disk in plaintext. It is also the part almost everyone
leaves unencrypted, and the part that, on a correctly configured machine,
does not need any extra work.

The reason for that last sentence is not that swap is harmless. It is that on
this box swap already lives *inside* the LUKS container, so the bytes leaving
the drive are already ciphertext. This page explains when that is true, when it
is not, and what to do in each case.

Nothing on this page has been applied — it is documentation only. The one
exception is noted in the next section: a `swapoff` has already been run on
this machine, so the live state is mid-change.

---

## Right now on this machine

Before anything else, the actual live state — which is not what `/etc/fstab`
claims:

```bash
cat /proc/swaps
```

```
Filename    Type       Size       Used  Priority
/dev/zram0  partition  3946492    1464256  100
```

`zram0` is active. **`/swap/swapfile` is not.** The fstab entry is still there
but the unit is dead:

```
swap-swapfile.swap   loaded inactive dead   /swap/swapfile
```

The boot log shows it *did* come up, and was then taken down again:

```
kernel: Adding 3946492k swap on /dev/zram0.  Priority:100 extents:1 across:3946492k SSDsc
kernel: Adding 4194300k swap on /swap/swapfile.  Priority:-1 extents:2 across:5465700k SS
systemd[1]: Activating swap /swap/swapfile...
```

```
$ systemctl status swap-swapfile.swap
     Active: inactive (dead) since Sat 2026-09-26 20:01:04 -03
   Duration: 3h 49min 6.358s
```

So a `swapoff` was run a few hours into the session and nothing else followed.
This is a half-finished Option A: the file is off, but it still exists, zram is
still only 3.8 GiB, and the fstab entry will bring the swapfile straight back
on the next reboot. Either finish the job or put it back — see
*Finish Option A* below.

Note `extents:2` in that kernel line. "Preallocated" is not the same as
"contiguous" — the 4 GiB file is two extents, and `across:5465700k` is the
physical space those two occupy (over 5 GiB, because of chunk rounding). Both
extents are on the same device and data profile, which is what the kernel
actually requires, so this is valid. It does mean swap I/O is touching two
disjoint regions rather than one, which is a small and rarely measurable cost.

Two other facts worth having on the record:

```
$ cat /proc/cmdline
... zswap.enabled=0 ...
```

**zswap is disabled.** That is the other compressed-RAM swap path, and it is the
one that works transparently with no configuration. With it off, zram-generator
is your only compressed swap, which makes the `mem-size` setting below
load-bearing rather than cosmetic. Do not enable both at once unless you know
why you are doing it.

| Component | Size | Where it lives |
|---|---|---|
| RAM | 7.5 GiB | — |
| zram0 (zstd) | 3.8 GiB, holding 1.3 GiB at 3.2:1 | RAM |
| `/swap/swapfile` | 4 GiB | `/swap` subvol, inside LUKS2 — **inactive** |

---

## How it fits together

```
        your processes
              |  anonymous + page cache pressure
              v
        +-------------+      eviction         +--------------+
        |    RAM      | ----------------------> |    swap      |
        +-------------+                         +--------------+
              ^                                     |          |
              |  swap-in                     write |          | read
              +-------------------------------------+          v
                                                       +--------------+
                                                       |    disk     |
                                                       +--------------+
                                                            ^
    LUKS2 boundary -------------------------------------+-- encrypts here
    (nvme0n1p2 -> root -> btrfs)                              already
```

The single most useful question is **where the LUKS boundary sits relative to
the swap device**. Not "is swap encrypted", but "is swap inside the encrypted
volume".

On this machine:

```
nvme0n1
├── nvme0n1p1   vfat          EFI, unencrypted, harmless
└── nvme0n1p2   crypto_LUKS   <- the boundary
    └── root    btrfs
        ├── /               subvol @     <- contains everything
        └── /swap           subvol @swap <- contains /swap/swapfile
```

`/swap` is a subvolume *of the LUKS2 root*. Every byte the kernel writes to
`/swap/swapfile` is written through dm-crypt first. Pull the NVMe out of a
running-then-hard-powered-off machine and `strings` finds nothing.

---

## The threat model

What swap actually leaks is **whatever the kernel happened to evict**. That
includes things you would never put in a disk encryption threat model:

| Leaked from swap | Examples |
|---|---|
| Cryptographic keys | SSH agent sockets, GnuPG keyring cache, `~/.ssh` page cache |
| Session material | TLS session tickets, browser cookie cache, OAuth tokens in memory |
| Typed secrets | passwords, form fields, chat drafts not yet flushed to disk |
| Process memory | anything a core dump would have caught, minus the effort |

Note what is *not* on that list: the disk encryption key. LUKS master keys stay
in kernel memory and are small and hot, so they are the last thing to be
evicted. Cold-boot attacks target the keyslots directly and swap is irrelevant
to them.

So swap encryption is worth doing when:

1. **Swap sits outside the encrypted volume.** A second bare disk, a partition
   shared with Windows, a USB stick, a `swapfile` on an unencrypted `/boot`.
   This is the real case. LUKS protects a *device*, not a *filesystem*, so
   anything the kernel writes to another device is plaintext on that device.
2. **You hibernate.** Hibernate serialises RAM to swap on the way down and
   reads it back on the way up. It is the one case where swap contents are
   written in bulk, deliberately, on every cycle.
3. **You want to shrink the blast radius of a live system.** Defence in depth:
   once the volume is unlocked, `/dev/mapper/root` is readable by anything that
   gets code execution, and swap is a second path to the same plaintext. LUKS
   on swap does *not* help here — see the next section.

And is not worth doing when swap is already inside LUKS and you do not hibernate.

---

## Rule 0: encryption is a boundary, not a property

The instinct is "encrypt swap so it is encrypted". But dm-crypt needs the key
to decrypt, and the key is in kernel memory for as long as the volume is open.
An attacker who can read the decrypted swap device is, by definition, either
running code on the machine or holding your LUKS passphrase. In both cases they
can read `/dev/mapper/root` and read swap through the filesystem just as
easily.

Wrapping swap in a second layer of LUKS buys you exactly one thing: it costs
them the "just dump the raw swap device" shortcut. It does not stop a
determined attacker, and it costs you a boot-time unlock prompt, a keyfile, or
an initramfs change.

So the honest decision tree is:

- swap inside the LUKS volume, no hibernate → **do nothing, or delete it for zram**
- swap outside the LUKS volume → **encrypt it, this is real**
- you hibernate → **encrypt it, and the unlock must be possible pre-resume**

That is the whole decision. Everything below is implementation.

---

## What to pick

| Option | Encrypted | Works on btrfs | Survives reboot | Boot prompt | Verdict |
|---|---|---|---|---|---|
| **A. zram only** | n/a (never hits disk) | yes | yes | no | **Default choice** |
| **B. LUKS2 swap partition** | yes, real | yes (btrfs shrinks) | yes | none w/ keyfile | Use if you need disk swap |
| **C. LUKS2 over loop file** | yes, real | **no** | yes | none w/ keyfile | Avoid on btrfs |
| D. btrfs swapfile + LUKS | — | **impossible** | — | — | See *Why not* below |

---

## Option A — zram only (recommended here)

zram is a compressed block device **in RAM**. Swap written to it is compressed
and then lives in anonymous memory, which never reaches the platter. There is
nothing to encrypt because there is no disk involved — the question does not
apply.

Live state:

```
$ zramctl
NAME       ALGORITHM DISKSIZE DATA  COMPR  TOTAL STREAMS MOUNTPOINT
/dev/zram0 zstd          3.8G 1.3G 401.4M 412.1M         [SWAP]
```

3.8 GiB of zram on 7.5 GiB of RAM, holding 1.3 GiB of data in 401 MiB of actual
memory. That is a 3.2:1 ratio and it is doing all the work — there is currently
no disk swap active at all. zram is not a "safety net" here, it *is* the swap.

Size zram to a fraction of RAM and drop the disk file:

```bash
sudoedit /etc/systemd/zram-generator.conf
```

```ini
[zram0]
compression-algorithm = zstd
mem-size = 50%
swap-priority = 100
```

```bash
sudo swapoff /swap/swapfile
sudo systemctl restart systemd-zram-setup@zram0.service
swapon --show
```

`swap-priority = 100` matters more than it looks. The kernel fills the *highest*
priority swap device first, so zram must outrank disk. An fstab swap line with
no `pri=` gives **-1**, so `100` already wins comfortably — that is why the boot
log shows zram filling before the swapfile. But any disk swap at a *higher*
priority than zram silently defeats the whole arrangement, which is the failure
mode to watch for.

If you want a hard guarantee that the disk is never used, give disk swap a
priority below `-2` so it is unambiguously the last resort, or remove it. With
`mem-size = 50%` on 7.5 GiB you get ~3.75 GiB of zram, and the live ratio here
is 3.2:1, so that is roughly 12 GiB of apparent swap against 7.5 GiB of real
RAM. A disk swapfile will essentially never be reached.

### If you keep a btrfs swapfile

Two corrections to `/etc/fstab`, which currently has problems beyond encryption:

```
UUID=cb496a89-...  /swap  btrfs  rw,relatime,compress=zstd:3,...  0 0
UUID=cb496a89-...  /swap  btrfs  rw,relatime,compress=zstd:3,...  0 0
/swap/swapfile     none  swap   defaults                          0 0
```

- **The `/swap` mount is listed twice.** Harmless — the second is a no-op — but
  delete one.
- **`compress=zstd:3` must go.** A btrfs swapfile is required to be NOCOW, and
  a NOCOW inode can never be compressed. The per-file `+C` flag is what actually
  enforces this, so the option is inert today, but it is misleading and it will
  silently do nothing on any file you forget to `chattr`.
- **Add `noatime`.** Every swap-in is a read, and the default `relatime` still
  updates atime on first access per day, generating pointless writes to an SSD.

```
UUID=cb496a89-...  /swap  btrfs  rw,relatime,noatime,ssd,subvol=/@swap  0 0
/swap/swapfile     none  swap   defaults,pri=-2                         0 0
```

`pri=-2` is belt-and-braces: `defaults` already resolves to -1, which zram
beats at 100, so this only matters if you ever set zram's priority lower.

Rebuild the file the supported way — since kernel 6.1 there is a single command
that gets every constraint right:

```bash
sudo swapoff /swap/swapfile
sudo rm /swap/swapfile
sudo btrfs filesystem mkswapfile --size 4G /swap/swapfile
sudo swapon /swap/swapfile
```

The manual equivalent, if you want to see what the tool does:

```bash
truncate -s 0 /swap/swapfile
chattr +C /swap/swapfile
fallocate -l 4G /swap/swapfile
chmod 0600 /swap/swapfile
mkswap /swap/swapfile
```

### Finish Option A

The machine is half-way through this option right now: swapfile off, fstab
untouched. Pick a branch and take it to the end.

**Go all the way — zram only.** The state after the last reboot should have no
swapfile in `/proc/swaps` and no swap entry in fstab:

```bash
# 1. zram sized to RAM, highest priority
sudoedit /etc/systemd/zram-generator.conf     # mem-size = 50%, swap-priority = 100

# 2. remove the file for good
sudo swapoff /swap/swapfile
sudo rm /swap/swapfile

# 3. drop the two /swap lines from /etc/fstab, or the file will be missed
#    at boot and systemd will wait on a missing unit
sudoedit /etc/fstab

# 4. drop the now-unused subvolume
sudo btrfs subvolume delete /swap

# 5. re-create zram at the new size
sudo systemctl daemon-reload
sudo systemctl restart systemd-zram-setup@zram0.service

# 6. confirm
cat /proc/swaps
zramctl
```

Step 5 is the one people miss. Editing the generator config does not resize a
live device; without the restart, `zramctl` keeps reporting 3.8G and you will
think the setting was ignored.

**Or put it back** — if the disk swapfile is wanted after all, just reactivate
it and fix the fstab problems above:

```bash
sudo swapon /swap/swapfile
```

Either way, `systemctl status swap-swapfile.swap` should agree with
`cat /proc/swaps` when you are done.

---

## Option B — LUKS2 encrypted swap partition

The only method that produces a genuinely separately-encrypted swap area. It
needs a real block device, because dm-crypt addresses data at fixed offsets and
a partition has them for free.

There is free space: 35 GiB used of 238 GiB. Shrink btrfs to make room.

```bash
# 1. Shrink btrfs, leaving 9G. Do this with swap OFF so the extents are not
#    pinned, or the shrink will fail.
sudo swapoff /swap/swapfile
sudo btrfs filesystem resize -9G /

# 2. Create the partition. cfdisk, or from a live USB / gparted.
sudo cfdisk /dev/nvme0n1
#    n -> new partition, default start, 9G, type 82 (Linux swap)
#    w -> write

sudo partprobe /dev/nvme0n1    # or reboot
lsblk /dev/nvme0n1
```

Format as LUKS2. The default 1 MiB data offset is already 4K-aligned, which is
what `mkswap` requires, so no `--align-payload` games:

```bash
sudo cryptsetup luksFormat --type luks2 --batch-mode /dev/nvme0n1p3
sudo cryptsetup luksUUID /dev/nvme0n1p3
```

### A keyfile, so nothing prompts at boot

You do not want to type a passphrase for swap on every boot. Since root is
already unlocked by the time swap is set up, a root-only keyfile on the
encrypted root is sufficient — anything that can read it has already defeated
the outer LUKS.

```bash
sudo install -m 0400 -o root -g root /dev/urandom /etc/cryptswap.key
```

`/etc/crypttab`:

```
swapcrypt  /dev/disk/by-uuid/<luks-uuid>  /etc/cryptswap.key  luks,swap,noauto
```

The options do real work here:

| Option | Effect |
|---|---|
| `luks` | Use the LUKS format rather than a plain dm-crypt mapping |
| `swap` | Run `mkswap` on the opened device. Implies `plain`. **Destroys contents every boot** — which is correct for swap |
| `noauto` | Do not add it to `cryptsetup.target`; let the fstab swap entry pull it in instead |

`swap` running `mkswap` on every boot is a feature, not a bug: it means the
swap signature is fresh each time and you never have to think about a stale
header after resizing the partition.

`/etc/fstab`, replacing the swapfile line:

```
/dev/mapper/swapcrypt  none  swap  defaults,pri=-2,noatime  0 0
```

```bash
sudo systemctl daemon-reload
sudo swapon --show
```

systemd's fstab generator will add the ordering dependency that unlocks
`swapcrypt` before `swapon` touches it, so there is nothing else to wire.

### Random swap UUID

`mkswap` without options generates a **version 1, time-based UUID**, which
encodes the moment it ran. Prefer a random one:

```bash
sudo mkswap --uuid random /dev/mapper/swapcrypt
```

(Only needed if you ran `mkswap` by hand. The `swap` crypttab option does not
let you choose, but it also regenerates the header every boot, so the leak does
not persist.)

### If you ever enable hibernate

Then the keyfile must be readable in the initramfs, before the resume happens,
or resume fails and you lose the session. That is a different configuration and
it is deliberately not covered here — this machine has no `disk` in
`/sys/power/mem_sleep`, only `s2idle`, so it cannot hibernate.

For the record, the two changes are: put the key at `/etc/crypttab.key`, add
`KEYFILE=/etc/crypttab.key` to the `encrypt` hook in `/etc/mkinitcpio.conf`,
and rebuild with `sudo mkinitcpio -P`. Add
`rd.luks.options=luks2-name=/swapcrypt` too. You would also need the
hibernate hook, and for a swap *partition* the resume offset is simply the
partition start, whereas a swapfile needs `btrfs inspect-internal map-swapfile`.

---

## Option C — LUKS2 over a loop file

```bash
sudo dd if=/dev/zero of=/swap/luks-swap bs=1M count=8192 status=progress
sudo cryptsetup luksFormat --type luks2 /swap/luks-swap
sudo cryptsetup open /swap/luks-swap swapcrypt
sudo mkswap --uuid random /dev/mapper/swapcrypt
sudo swapon /dev/mapper/swapcrypt
```

This is the standard answer you will find online, and it is fine on ext4 or XFS.
**On btrfs it is unsound**, and since your root is btrfs, treat it as a
non-option unless you put the image on a different filesystem. See below.

---

## Why a btrfs swapfile cannot be encrypted

dm-crypt presents a block device whose byte *N* is always at a fixed offset.
A file has no such guarantee, and on btrfs specifically:

- **Blocks move.** btrfs relocates extents for balance, defragmentation, device
  add/replace and automatic balancing. A swap device must never move its blocks
  once assigned. A swapfile works only because the kernel pins its extents.
- **Copy-on-write.** A NOCOW file is required. That is fine, but it means you
  are already working around the filesystem's normal semantics, and a loop
  device layered on top re-introduces the fixed-offset assumption btrfs cannot
  make.
- **Compression is forbidden** on the file, and a compressed subvolume is a
  silent footgun.
- **Snapshots.** The subvolume holding an active swapfile cannot be snapshotted.
- **balance and scrub skip block groups** containing swapfile extents, which
  degrades verification for everything else in those groups. The btrfs docs
  single out the root filesystem as especially bad for this. You are on a
  root-filesystem swapfile right now.

The requirements, for reference:

| Requirement | Enforced by |
|---|---|
| single device, single data profile | layout, not user-controllable |
| no holes, preallocated | `fallocate` / `btrfs filesystem mkswapfile` |
| NOCOW, no datasum, no compression | `chattr +C` on the file |
| cannot be snapshotted while active | automatic |
| 4K aligned | `mkswap` |

`btrfs inspect-internal map-swapfile` validates all of them and is the fastest
way to find out why `swapon` failed:

```bash
sudo btrfs inspect-internal map-swapfile /swap/swapfile
```

So: **a btrfs swapfile cannot be encrypted. It does not need to be, if it lives
inside LUKS.** If it does not live inside LUKS, the answer is Option B — give
it a real partition.

---

## Verify

```bash
# 1. What is actually active right now. /proc/swaps is the ground truth;
#    `swapon --show` only lists what is up.
cat /proc/swaps
zramctl

# 2. Is the swap device inside the LUKS volume? This is the question that
#    matters, and `findmnt -T` is the way to ask -- `lsblk` refuses a
#    swapfile ("not a block device") and tells you nothing useful.
findmnt -no SOURCE -T /swap/swapfile
#   -> /dev/mapper/root[/@swap]     i.e. inside the LUKS2 volume

# 3. Confirm the LUKS boundary and that nothing is a bare partition
lsblk -o NAME,TYPE,FSTYPE /dev/nvme0n1

# 4. Confirm the swapfile is NOCOW and fully allocated
sudo lsattr /swap/swapfile          # must contain "C" in the flags
sudo filefrag -v /swap/swapfile     # one contiguous extent, holes column 0
sudo btrfs inspect-internal map-swapfile /swap/swapfile   # validates everything

# 5. Prove the disk holds no plaintext: needs sudo, and a bit of patience
sudo strings -a /dev/nvme0n1 | grep -m1 -i 'known-plaintext-marker'
```

Step 2 is the single most useful command on this page. A `SOURCE` of
`/dev/mapper/root[...]` means dm-crypt is already in the write path, and the
encryption question is settled. A `SOURCE` that is a bare `/dev/sdX1` means it
does not, and Option B applies.

Step 5 is the empirical version. Put a short marker string in a file, then grep
the raw device for it. If the search comes back empty while the file is still
in page cache, the bytes on the platter are ciphertext.

For zram instead:

```bash
zramctl                          # sizes, algorithm, mem limit
cat /sys/block/zram0/mm_stat     # orig_data_size, compr_data_size, mem_used_total
```

A `compr_data_size` well under `orig_data_size` is the compression ratio — the
number that tells you whether 3.8 GiB of zram is enough.

---

## Troubleshooting

**`swapon: /swap/swapfile: swapon failed: Invalid argument`.**
`swapon` never tells you why. btrfs logs the real reason:

```bash
journalctl -t kernel -b | grep -i -e swap -e btrfs
```

Common causes: file not NOCOW, has holes, was compressed, or spans multiple
devices/data profiles. `sudo btrfs inspect-internal map-swapfile /swap/swapfile`
checks all of them at once.

**`swapon` works but `btrfs balance` complains or skips block groups.**
Expected. Active swapfile extents are skipped. Run `balance` with swap off, or
accept the reduced coverage. `scrub` behaves the same way.

**Cannot snapshot the `@swap` subvolume.**
Also expected while swap is active. `sudo swapoff /swap/swapfile` first. Note
that a subvolume which has *ever* held a snapshotted swapfile cannot have a new
one activated.

**Boot hangs at the swap entry after setting up Option B.**
The crypt device was not unlocked before `swapon` ran. Check that the crypttab
line has `noauto` (so it is not double-registered in `cryptsetup.target`) and
that you ran `sudo systemctl daemon-reload`. `systemctl status swapcrypt` and
`journalctl -b -u swapcrypt` will say which half failed.

**Boot prompts for a passphrase you did not expect.**
The crypttab entry is missing `noauto`, or the keyfile path is wrong or not
mode `0400` root-owned. `sudo ls -l /etc/cryptswap.key`.

**`Cannot resize: free space too small` or the shrink refuses.**
Active swap pins its extents. `sudo swapoff` before `btrfs filesystem resize`.

**zram not sized as configured.**
`zram-generator.conf` is read by a *generator*, not by the unit at runtime, so
editing it does nothing until the generated unit is rebuilt and the device is
recreated. Both halves are required, in this order:

```bash
sudo systemctl daemon-reload                            # re-run the generator
sudo systemctl restart systemd-zram-setup@zram0.service  # recreate the device
zramctl                                                 # confirms what is live
```

Skipping `daemon-reload` is the usual cause: the restart re-runs the *old*
generated unit with the *old* size and you conclude the config was ignored.

---

## Rollback

Everything below is reversible without touching LUKS on your root.

Order matters in one direction only: **fstab before deleting anything.** Remove
the fstab entry first, or the next boot waits forever on a device you just
deleted. Run `findmnt /swap && cat /proc/swaps` afterwards to confirm nothing is
still referenced.

```bash
# --- Option A rollback: bring the disk swapfile back
sudo swapon /swap/swapfile

# --- Option A, the other branch: zram only, for good
# 1. fstab first
sudoedit /etc/fstab                        # drop /swap/swapfile, then the /swap mount
# 2. then remove
sudo swapoff /swap/swapfile
sudo rm /swap/swapfile
sudo btrfs subvolume delete /swap          # only once nothing mounts it
# 3. leave the /swap mountpoint, or rmdir it
sudo rmdir /swap

# --- Option B rollback: destroy the encrypted swap partition
sudo swapoff /dev/mapper/swapcrypt
sudo cryptsetup close swapcrypt
sudo cryptsetup erase --batch-mode /dev/nvme0n1p3   # wipe the LUKS header
sudo wipefs -a /dev/nvme0n1p3
sudoedit /etc/fstab /etc/crypttab          # drop swapcrypt and its swap line
sudo rm /etc/cryptswap.key
# then delete the partition with cfdisk and give the space back to btrfs:
sudo btrfs filesystem resize max /
```

`swapoff` before `cryptsetup erase` is not optional — erasing a LUKS header
underneath an active swap device leaves dm-crypt writing to uninitialised
space, and the next boot reads a header that is not there.

---

## The short version

Swap holds plaintext copies of your RAM. Whether that matters depends entirely
on whether the swap device is inside the LUKS volume.

- Already inside LUKS, no hibernate → nothing to do. Consider zram and deleting
  the swapfile, for performance and for balance/scrub coverage, not for secrecy.
- Outside LUKS → it needs a partition, LUKS2, and a keyfile.
- A btrfs swapfile can never be encrypted. It does not need to be.

## Related

- `arch-setup.md` — the system this page describes

---
title: "Creating an Initramfs for Kernel Development"
aliases:
  - initramfs
  - initrd
  - init.cpio
  - busybox initramfs
  - kernel initramfs
  - gen_init_cpio
  - mkinitcpio
description: >-
  How to create an initramfs (init.cpio) for Linux kernel development: using the kernel's
  gen_init_cpio tool, cpio directly, BusyBox, mkinitcpio, and buildroot. Covers booting
  in QEMU, adding custom test binaries, repacking existing initramfs images, and the
  full edit-build-boot-debug loop.
tags:
  - arch-linux
  - linux
  - kernel
  - initramfs
  - qemu
  - debugging
  - development
  - guide
categories: linux
type: guide
status: draft
created: 2026-09-28
updated: 2026-09-28
last_reviewed: 2026-09-28
review_after: 2027-03-28
language: en
audience: sysadmin
scope: initramfs creation for kernel development and debugging
platform:
  - Arch Linux
  - Linux
keywords:
  - initramfs
  - initrd
  - init.cpio
  - gen_init_cpio
  - gen_initramfs.sh
  - busybox
  - mkinitcpio
  - buildroot
  - cpio
  - QEMU -initrd
  - vmlinux
  - nokaslr
  - CONFIG_INITRAMFS_SOURCE
  - CONFIG_GDB_SCRIPTS
sources:
  - "[Early userspace support — Linux Kernel Docs](https://docs.kernel.org/driver-api/early-userspace/early_userspace_support.html)"
  - "[Initramfs buffer format — Linux Kernel Docs](https://docs.kernel.org/driver-api/early-userspace/buffer-format.html)"
  - "[Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugging/gdb-kernel-debugging.html)"
  - "[Linux basic initramfs — blog.izissise.net](https://blog.izissise.net/posts/initramfs/)"
  - "[Build a kernel, initramfs and Busybox — cylab.be](https://cylab.be/blog/320/build-a-kernel-initramfs-and-busybox-to-create-your-own-micro-linux)"
  - "[Kernel Debugging using QEMU and GDB — W4118](https://w4118.github.io/guides/qemu.html)"
  - "[Debugging the Linux Kernel with Qemu and GDB — YouTube](https://www.youtube.com/watch?v=2VcA5Wj7IvU)"
  - "[Debugging the Linux Kernel — YouTube](https://www.youtube.com/watch?v=7QiR3TOYajY)"
source_retrieved: 2026-09-28
related:
  - "[[kernel-dev-debugging]]"
  - "[[libvirt-virt-manager]]"
  - "[[qemu-automated-testing]]"
  - "[[arch-setup]]"
  - "[[Vault Conventions]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document initramfs creation for kernel development"
ai-review: pending
---

# Creating an Initramfs for Kernel Development

> [!summary] The one-paragraph answer
> An initramfs is a compressed cpio archive containing a minimal root filesystem that
> the kernel mounts during boot. For kernel development, it provides a tiny userspace
> with just enough tools to test kernel changes. Create it with the kernel's
> `gen_init_cpio` tool, plain `cpio`, BusyBox, or `mkinitcpio`. Boot it in QEMU with
> `-initrd initramfs.cpio.gz`. The initramfs must contain an `/init` executable —
> without it, the kernel panics with "No working init found."

---

## Context

When you build and boot a custom kernel in QEMU, the kernel needs a userspace to
pivot to after boot. An initramfs provides that userspace as a small, self-contained
cpio archive. It is the standard way to test kernel changes without a full disk
image.

This guide covers multiple methods to create an initramfs, from minimal (a single
static binary) to practical (BusyBox with a shell). It also covers how to add
custom test binaries for syscall testing and how to repack existing initramfs
images.

See [[kernel-dev-debugging]] for the full GDB debugging workflow that uses the
initramfs created here.

---

## Details

### 1. What is an initramfs?

An initramfs is a compressed cpio archive (usually gzip) that the kernel unpacks
into a ramfs filesystem during boot. The kernel then runs `/init` from this
filesystem as PID 1.

The format:

```
initramfs := ("\0" | cpio_archive | cpio_compressed_archive)*
cpio_compressed_archive := GZIP(cpio_archive) | BZIP2 | LZMA | XZ | LZO | LZ4 | ZSTD
```

Key properties:
- The archive uses the "newc" cpio format (`cpio -H newc`)
- It can be compressed with gzip, bzip2, lzma, xz, lzo, lz4, or zstd
- The kernel auto-detects the compression type
- Only one `/init` executable is needed — everything else is optional

### 2. Method 1: Minimal initramfs with gen_init_cpio

The kernel source includes `usr/gen_init_cpio.c` — a tool that builds a cpio archive
from a text description file. This is the most flexible method.

**Step 1: Build gen_init_cpio**

```bash
cd ~/linux/
make -C usr gen_init_cpio
```

**Step 2: Create a description file**

```bash
# initramfs_list
dir /          0755 0 0
dir /bin       0755 0 0
dir /dev       0755 0 0
dir /proc      0755 0 0
dir /sys       0755 0 0
dir /mnt       0755 0 0
nod /dev/console 0600 0 0 c 5 1
file /init     /path/to/your/init 0755 0 0
```

**Step 3: Generate the cpio archive**

```bash
usr/gen_init_cpio initramfs_list | gzip -9 > initramfs.cpio.gz
```

**Description file syntax:**

| Directive | Meaning |
|---|---|
| `dir <name> <mode> <uid> <gid>` | Create a directory |
| `file <name> <source> <mode> <uid> <gid>` | Include a file from the host |
| `nod <name> <mode> <uid> <gid> <type> <maj> <min>` | Create a device node |
| `slink <name> <target> <mode> <uid> <gid>` | Create a symbolic link |
| `pipe <name> <mode> <uid> <gid>` | Create a named pipe |
| `sock <name> <mode> <uid> <gid>` | Create a socket |

### 3. Method 2: Direct cpio (simplest)

For a quick initramfs with a single binary:

```bash
# Create a directory with your init binary
mkdir -p initramfs
cp my-test-binary initramfs/init
chmod +x initramfs/init

# Create the cpio archive
cd initramfs
find . | cpio -H newc -o | gzip -9 > ../initramfs.cpio.gz
cd ..
```

Or even simpler — pipe directly without a directory:

```bash
echo init | cpio -H newc -o | gzip -9 > initramfs.cpio.gz
```

### 4. Method 3: BusyBox initramfs (recommended for development)

BusyBox provides a full set of Unix tools in a single static binary. This is the
most practical option for kernel development.

**Step 1: Build static BusyBox**

```bash
# Download and extract BusyBox
wget https://busybox.net/downloads/busybox-1.36.1.tar.bz2
tar xf busybox-1.36.1.tar.bz2
cd busybox-1.36.1

# Configure for static build
make menuconfig
# Enable: Settings → Build static binary (no shared libs)

make -j$(nproc)
make install
# This creates _install/ with all binaries
```

**Step 2: Create the initramfs structure**

```bash
mkdir -p initramfs
cp -a busybox-1.36.1/_install/* initramfs/

# Create the init script
cat > initramfs/init << 'EOF'
#!/bin/sh

mount -t devtmpfs devtmpfs /dev
mount -t proc      proc      /proc
mount -t sysfs     sysfs     /sys
mount -t tmpfs     tmpfs     /tmp

echo "Kernel dev initramfs ready"
exec /bin/sh
EOF
chmod +x initramfs/init
```

**Step 3: Create the cpio archive**

```bash
cd initramfs
find . | cpio -H newc -o | gzip -9 > ../initramfs.cpio.gz
cd ..
```

### 5. Method 4: mkinitcpio (Arch Linux)

On Arch Linux, `mkinitcpio` is the standard tool for creating initramfs images.

```bash
# Create a minimal mkinitcpio config
cat > /tmp/mkinitcpio-debug.conf << 'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev modconf block filesystems keyboard fsck)
EOF

# Create a custom init script
mkdir -p /tmp/initramfs-rootfs
cat > /tmp/initramfs-rootfs/init << 'EOF'
#!/bin/sh
mount -t devtmpfs devtmpfs /dev
mount -t proc      proc      /proc
mount -t sysfs     sysfs     /sys
exec /bin/sh
EOF
chmod +x /tmp/initramfs-rootfs/init

# Build the initramfs
mkinitcpio -c /tmp/mkinitcpio-debug.conf -g /tmp/initramfs-debug.img
```

For a truly minimal initramfs with BusyBox on Arch:

```bash
sudo pacman -S busybox
mkinitcpio -c /etc/mkinitcpio.conf -g /boot/initramfs-debug.img
```

### 6. Method 5: Buildroot (automated)

Buildroot can generate a minimal rootfs as a cpio archive:

```bash
git clone https://github.com/buildroot/buildroot.git
cd buildroot

cat > configs/minimal_ramdisk_defconfig << 'EOF'
BR2_x86_64=y
BR2_TARGET_ROOTFS_CPIO=y
BR2_TARGET_ROOTFS_CPIO_GZIP=y
EOF

make minimal_ramdisk_defconfig
make -j$(nproc)

# Output: output/images/rootfs.cpio.gz
```

### 7. Booting the initramfs in QEMU

```bash
qemu-system-x86_64 \
  -kernel arch/x86/boot/bzImage \
  -initrd initramfs.cpio.gz \
  -append "console=ttyS0 nokaslr" \
  -nographic \
  -s -S
```

| Flag | Purpose |
|---|---|
| `-kernel` | The compiled kernel (bzImage) |
| `-initrd` | The initramfs cpio archive |
| `-append` | Kernel command line |
| `-nographic` | Redirect serial to stdio |
| `-s` | GDB stub on port 1234 |
| `-S` | Freeze CPU at startup |

### 8. Adding custom test binaries

To test kernel changes (e.g. new syscalls), add statically-linked binaries to the
initramfs:

```bash
# Build a static test binary
gcc -static -o test-syscall test-syscall.c

# Add it to the initramfs
mkdir -p initramfs/test
cp test-syscall initramfs/test/

# Repack
cd initramfs
find . | cpio -H newc -o | gzip -9 > ../initramfs.cpio.gz
cd ..
```

Inside the VM, run the test:

```bash
(initramfs) ./test/test-syscall
```

### 9. Repacking an existing initramfs

To modify an existing initramfs (e.g. the one from your distro):

```bash
# For gzip-compressed initramfs
mkdir initrd && cd initrd
zcat /boot/initramfs-$(uname -r).img | cpio -idm

# Make your changes
vim init

# Repack
find . | cpio -H newc -o | gzip -9 > ../custom-initramfs.img
cd ..
```

For Arch's mkinitramfs format (multi-stage):

```bash
mkdir initrd && cd initrd
unmkinitramfs /boot/initramfs-$(uname -r).img .

# Edit the main stage
cd main
vim init

# Repack
find . | cpio -H newc -o | gzip -9 > ../../custom-initramfs.img
cd ../..
```

### 10. Building initramfs into the kernel

You can embed the initramfs directly into the kernel image:

```bash
# Point CONFIG_INITRAMFS_SOURCE at a cpio file or directory
./scripts/config --file .config \
  -e INITRAMFS_SOURCE \
  --set-str INITRAMFS_SOURCE "/path/to/initramfs.cpio.gz" \
  -e INITRAMFS_COMPRESSION_GZIP
make olddefconfig
make -j$(nproc)
```

The resulting bzImage will contain the initramfs — no `-initrd` flag needed.

---

## Gotchas

> [!warning] /init must exist and be executable
> The kernel runs `/init` from the initramfs as PID 1. If it does not exist or is
> not executable, the kernel panics with "No working init found." Always ensure
> your initramfs contains an executable `/init`.

> [!warning] Static binaries only
> The initramfs environment has no dynamic linker. All binaries must be statically
> linked (`gcc -static`) or use BusyBox which is built as a static binary.

> [!warning] Device nodes need mknod
> If your init script mounts filesystems, you need `/dev/console`. Either create
> it with `nod /dev/console 0600 0 0 c 5 1` in gen_init_cpio, or use devtmpfs
> (`mount -t devtmpfs devtmpfs /dev`) which auto-creates device nodes.

> [!tip] Use devtmpfs instead of static device nodes
> Add `mount -t devtmpfs devtmpfs /dev` to your init script. This auto-creates
> all device nodes and is much simpler than listing them manually.

> [!tip] Uncompressed cpio works too
> QEMU and the kernel accept uncompressed cpio archives. Skip the `gzip -9` step
> if you want faster iteration during development.

> [!tip] Loopback for disk-based testing
> If you need a real filesystem (not just ramfs), create a ext4 image and use
> the `loop` module:
> ```bash
> dd if=/dev/zero of=/tmp/rootfs.img bs=1M count=64
> mkfs.ext4 /tmp/rootfs.img
> # In QEMU: -drive file=/tmp/rootfs.img,format=raw
> # In init: mount /dev/sda /mnt
> ```

---

## Verification

After creating the initramfs, verify it works:

```bash
# 1. Check the archive is valid
zcat initramfs.cpio.gz | cpio -t | head
# Expected: list of files including "init"

# 2. Boot in QEMU
qemu-system-x86_64 \
  -kernel arch/x86/boot/bzImage \
  -initrd initramfs.cpio.gz \
  -append "console=ttyS0 nokaslr" \
  -nographic

# Expected: kernel boots, init script runs, you get a shell prompt

# 3. Verify inside the VM
(initramfs) ls /
(initramfs) cat /proc/version
(initramfs) uname -r
```

---

## Troubleshooting

### "No working init found. Try passing init= option to kernel."

The initramfs does not contain an executable `/init`. Check:

```bash
zcat initramfs.cpio.gz | cpio -t | grep init
# Should show: init
```

### "Kernel panic - not syncing: Attempted to kill init!"

The init process exited. Your init script must end with `exec /bin/sh` (or similar)
to keep a shell running. If the script just exits, the kernel panics.

### "mount: mounting proc on /proc failed: No such file or directory"

The `/proc` directory does not exist in the initramfs. Add it to the cpio:

```bash
mkdir -p initramfs/proc initramfs/sys initramfs/dev
```

### QEMU fails with "could not load kernel"

The bzImage may be stale. Rebuild:

```bash
make -j$(nproc)
```

---

## Related

- [[kernel-dev-debugging]] — full GDB debugging workflow using this initramfs
- [[libvirt-virt-manager]] — QEMU/KVM/libvirt setup for running the debug VM
- [[qemu-automated-testing]] — direct QEMU approach for automated kernel testing
- [[arch-setup]] — host machine setup; kernel build tools are part of provisioning
- [[Vault Conventions]] — this note's frontmatter schema and tag taxonomy

---

## Sources

- [Early userspace support — Linux Kernel Docs](https://docs.kernel.org/driver-api/early-userspace/early_userspace_support.html) — gen_init_cpio, CONFIG_INITRAMFS_SOURCE, initramfs format
- [Initramfs buffer format — Linux Kernel Docs](https://docs.kernel.org/driver-api/early-userspace/buffer-format.html) — cpio format specification
- [Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugging/gdb-kernel-debugging.html) — QEMU GDB stub, lx-* commands
- [Linux basic initramfs — blog.izissise.net](https://blog.izissise.net/posts/initramfs/) — gen_init_cpio usage, QEMU boot
- [Build a kernel, initramfs and Busybox — cylab.be](https://cylab.be/blog/320/build-a-kernel-initramfs-and-busybox-to-create-your-own-micro-linux) — BusyBox initramfs, QEMU testing
- [Kernel Debugging using QEMU and GDB — W4118](https://w4118.github.io/guides/qemu.html) — custom binaries in initramfs, repacking
- [Debugging the Linux Kernel with Qemu and GDB — YouTube](https://www.youtube.com/watch?v=2VcA5Wj7IvU) — video tutorial
- [Debugging the Linux Kernel — YouTube](https://www.youtube.com/watch?v=7QiR3TOYajY) — video tutorial with TUI

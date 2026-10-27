---
title: "Kernel Development with GDB Debugging on QEMU/KVM"
aliases:
  - kernel debugging
  - GDB kernel debug
  - QEMU GDB stub
  - kernel dev workflow
  - vmlinux GDB
  - kgdb QEMU
  - kernel debug info
description: >-
  Complete workflow for Linux kernel development using a pre-made kernel config, building
  with debug symbols, booting in QEMU/KVM with the GDB stub, and debugging with GDB and
  the kernel's helper scripts. Covers CONFIG_DEBUG_INFO, QEMU -s flag, lx-symbols,
  lx-dmesg, KGDB over serial, and the full edit-compile-boot-debug loop.
tags:
  - arch-linux
  - linux
  - kernel
  - debugging
  - gdb
  - qemu
  - kvm
  - development
  - guide
type: guide
status: draft
created: 2026-09-28
updated: 2026-09-28
last_reviewed: 2026-09-28
review_after: 2027-03-28
language: en
audience: sysadmin
scope: host-side kernel build + QEMU/KVM GDB debugging workflow
platform:
  - Arch Linux
  - Linux
keywords:
  - vmlinux
  - CONFIG_DEBUG_INFO
  - CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT
  - CONFIG_GDB_SCRIPTS
  - CONFIG_KGDB
  - CONFIG_KALLSYMS
  - CONFIG_FRAME_POINTER
  - nokaslr
  - QEMU -s
  - gdb vmlinux
  - lx-symbols
  - lx-dmesg
  - lx-lsmod
  - kgdboc
  - localmodconfig
  - scripts_gdb
  - target remote :1234
sources:
  - "[Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugging/gdb-kernel-debugging.html)"
  - "[Using kgdb, kdb and the kernel debugger internals — Linux Kernel Docs](https://docs.kernel.org/process/debugging/kgdb.html)"
  - "[How to quickly build a trimmed Linux kernel — Linux Kernel Docs](https://docs.kernel.org/admin-guide/quickly-build-trimmed-linux.html)"
  - "[Kdump — kexec-based Crash Dumping Solution — Linux Kernel Docs](https://docs.kernel.org/admin-guide/kdump/kdump.html)"
source_retrieved: 2026-09-28
related:
  - "[[libvirt-virt-manager]]"
  - "[[qemu-automated-testing]]"
  - "[[arch-setup]]"
  - "[[Vault Conventions]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document kernel development with GDB debugging"
ai-review: pending
---

# Kernel Development with GDB Debugging on QEMU/KVM

> [!summary] The one-paragraph answer
> Clone the kernel source, create a `.config` with `localmodconfig`, enable debug
> symbols (`CONFIG_DEBUG_INFO`, `CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT`,
> `CONFIG_KALLSYMS`, `CONFIG_KALLSYMS_ALL`, `CONFIG_GDB_SCRIPTS`), build with
> `make -j$(nproc)`, then boot the kernel in QEMU with `-s` (GDB stub on port 1234).
> Launch `gdb vmlinux`, connect with `target remote :1234`, and use the kernel's
> built-in GDB helper scripts (`lx-symbols`, `lx-dmesg`, `lx-lsmod`, `lx_current`,
> `lx_per_cpu`) to inspect the running kernel. The full loop is: edit → build →
> boot → debug → repeat.

---

## Context

You are developing or debugging the Linux kernel and need a fast, reproducible
workflow. You want to:

1. Build a kernel with full debug symbols
2. Boot it in a QEMU/KVM virtual machine
3. Attach GDB to the running kernel
4. Set breakpoints, inspect variables, and walk the call stack

This guide covers the complete workflow from source tree to debugging session,
using a pre-made kernel config as the starting point. It focuses on QEMU/KVM as
the target, but the same principles apply to KGDB over serial or JTAG.

See [[libvirt-virt-manager]] for the QEMU/KVM/libvirt setup, and
[[qemu-automated-testing]] for direct QEMU invocation without libvirt.

---

## Details

### 1. Install build dependencies

On Arch Linux:

```bash
sudo pacman -S --needed --noconfirm \
  bc binutils bison flex gcc git make openssl pahole perl \
  libelf python
```

For GDB with Python support (required for kernel helper scripts):

```bash
sudo pacman -S --needed --noconfirm gdb
```

### 2. Clone the kernel source

```bash
# Shallow clone of the latest stable master
git clone --depth 1 -b master \
  https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git ~/linux/
cd ~/linux/
```

To track a specific stable/longterm series:

```bash
git remote set-branches --add origin linux-6.1.y
git fetch --shallow-exclude=v6.0 origin
git checkout --detach origin/linux-6.1.y
```

### 3. Create a pre-made kernel config

Start from the running kernel's config, trimmed to currently loaded modules:

```bash
# Copy the running kernel's config as base
yes "" | make localmodconfig
```

This creates a `.config` that matches your hardware but disables everything not
currently loaded. It is the fastest path to a working config.

To start from the Arch default config instead:

```bash
cp /proc/config.gz . && zcat config.gz > .config
make olddefconfig
```

### 4. Enable debug symbols and GDB scripts

Enable the required config options for debugging:

```bash
./scripts/config --file .config \
  -d DEBUG_INFO_NONE \
  -e DEBUG_KERNEL \
  -e DEBUG_INFO \
  -e DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
  -e KALLSYMS \
  -e KALLSYMS_ALL \
  -e GDB_SCRIPTS \
  -e FRAME_POINTER
make olddefconfig
```

| Option | Why |
|---|---|
| `CONFIG_DEBUG_INFO` | Embeds DWARF debug info in vmlinux — required for source-level debugging |
| `CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT` | Use the toolchain's default DWARF version (5 on modern GCC) |
| `CONFIG_KALLSYMS` | Exposes kernel symbol table to GDB |
| `CONFIG_KALLSYMS_ALL` | Includes all symbols, not just functions |
| `CONFIG_GDB_SCRIPTS` | Builds the `vmlinux-gdb.py` helper module |
| `CONFIG_FRAME_POINTER` | Enables reliable stack frame walking |
| `CONFIG_DEBUG_KERNEL` | Master switch for kernel debugging features |

Disable KASLR for debugging (or use `nokaslr` on the kernel command line):

```bash
./scripts/config --file .config -d RANDOMIZE_BASE
make olddefconfig
```

> [!warning] Debug info is expensive
> A kernel built with `CONFIG_DEBUG_INFO` consumes ~5 GB of build artifacts
> (vs ~1 GB without). The vmlinux file itself will be several hundred MB.
> Disable debug symbols for production builds:
> ```bash
> ./scripts/config --file .config -d DEBUG_INFO \
>   -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT -d DEBUG_INFO_DWARF4 \
>   -d DEBUG_INFO_DWARF5 -e CONFIG_DEBUG_INFO_NONE
> make olddefconfig
> ```

### 5. Build the kernel

```bash
make -j$(nproc)
```

Key build artifacts:

| File | Purpose |
|---|---|
| `vmlinux` | Uncompressed kernel with debug symbols — **this is what GDB loads** |
| `arch/x86/boot/bzImage` | Compressed bootable kernel image |
| `System.map` | Symbol table for the running kernel |
| `vmlinux-gdb.py` | GDB Python helper module (built by `CONFIG_GDB_SCRIPTS`) |

Build the GDB scripts explicitly (required on kernels v5.1+):

```bash
make scripts_gdb
```

### 6. Prepare a bootable disk image

Create a minimal root filesystem for the VM:

```bash
# Create a disk image
qemu-img create -f qcow2 /tmp/kernel-dev.qcow2 10G

# Option A: Use an existing Arch ISO and install manually
# Option B: Use a pre-built rootfs (e.g. from virt-install or debootstrap)
# Option C: Boot with initramfs only (no disk needed for early-boot debugging)
```

For early-boot debugging, you can boot with just an initramfs and no disk:

```bash
# Build an initramfs with your test modules
mkinitcpio -c /etc/mkinitcpio.conf -g /tmp/initramfs-debug.img
```

### 7. Boot the kernel in QEMU with GDB stub

The `-s` flag tells QEMU to listen for GDB on port 1234:

```bash
qemu-system-x86_64 \
  -kernel arch/x86/boot/bzImage \
  -append "root=/dev/sda rw console=ttyS0 nokaslr" \
  -drive file=/tmp/kernel-dev.qcow2,format=qcow2 \
  -nographic \
  -s \
  -S
```

| Flag | Purpose |
|---|---|
| `-kernel` | Boot the kernel directly (no BIOS bootloader needed) |
| `-append` | Kernel command line — `nokaslr` disables KASLR so symbols match |
| `-drive` | Attach the root filesystem disk |
| `-nographic` | Redirect serial to stdio (no GUI window) |
| `-s` | Shorthand for `-gdb tcp::1234` — GDB stub on port 1234 |
| `-S` | Freeze CPU at startup (wait for GDB to continue) |

> [!tip] Omit -S to boot immediately
> Drop `-S` if you want the kernel to boot normally and attach GDB later.
> You can also start the GDB stub at runtime from the QEMU monitor with `gdbserver`.

### 8. Launch GDB and connect

In a separate terminal:

```bash
cd ~/linux/
gdb vmlinux
```

Inside GDB:

```gdb
# Allow auto-loading of the kernel's Python scripts
add-auto-load-safe-path /home/user/linux/

# Connect to the QEMU GDB stub
(gdb) target remote :1234

# Load kernel and module symbols
(gdb) lx-symbols

# Verify the connection works
(gdb) lx-dmesg
```

Expected output:

```
(gdb) target remote :1234
Remote debugging using :1234
0xffffffff81000000 in ?? ()

(gdb) lx-symbols
loading vmlinux
scanning for modules in /home/user/linux/
loading @0xffffffffa0020000: /home/user/linux/net/netfilter/xt_tcpudp.ko
...

(gdb) lx-dmesg
[    0.000000] Linux version 6.1.0-rc4-dbg+ (user@host) (gcc 12.2.0) #1 SMP
[    0.000000] Command line: root=/dev/sda rw console=ttyS0 nokaslr
...
```

### 9. Set breakpoints and debug

```gdb
# Break on a kernel function
(gdb) b start_kernel
(gdb) c

# Break on a module function (set before the module is loaded)
(gdb) b btrfs_init_sysfs
Make breakpoint pending on future shared library load? (y or [n]) y
(gdb) c

# Inspect the current task
(gdb) p $lx_current().pid
(gdb) p $lx_current().comm

# Inspect per-CPU variables
(gdb) p $lx_per_cpu(runqueues).nr_running

# Walk the call stack
(gdb) bt

# Continue execution
(gdb) c
```

### 10. Kernel GDB helper scripts

The kernel provides Python-based GDB commands when `CONFIG_GDB_SCRIPTS=y`:

| Command | Purpose |
|---|---|
| `lx-symbols` | (Re-)load symbols for vmlinux and all loaded modules |
| `lx-dmesg` | Print the kernel log buffer (dmesg) |
| `lx-lsmod` | List currently loaded kernel modules |
| `lx-current` | Return the current task's `task_struct` |
| `lx-module` | Find a module by name |
| `lx-per_cpu` | Return a per-CPU variable |
| `lx-task_by_pid` | Find a task by PID |
| `lx-thread_info` | Calculate thread_info from a task |

Convenience functions (usable in expressions):

```gdb
(gdb) p $lx_current()
(gdb) p $lx_per_cpu(runqueues)
(gdb) p $lx_module("btrfs")
```

### 11. KGDB over serial (alternative to QEMU GDB stub)

For debugging over a serial console (physical hardware or VM serial port):

```bash
# Kernel command line:
console=ttyS0,115200 kgdboc=ttyS0,115200 nokaslr kgdbwait
```

| Boot argument | Purpose |
|---|---|
| `kgdboc=ttyS0,115200` | Route KGDB over the first serial port at 115200 baud |
| `kgdbwait` | Stop at boot and wait for GDB to connect |
| `nokaslr` | Disable KASLR so symbol addresses match vmlinux |
| `kgdbcon` | Show printk messages inside GDB |

Connect from the host:

```bash
gdb ./vmlinux
(gdb) set serial baud 115200
(gdb) target remote /dev/ttyS0
```

To break into KGDB at runtime:

```bash
echo g > /proc/sysrq-trigger
```

### 12. The edit-compile-boot-debug loop

The full development cycle:

```bash
# 1. Edit source code
vim kernel/sched/core.c

# 2. Rebuild (only the changed files)
make -j$(nproc)

# 3. Rebuild GDB scripts if needed
make scripts_gdb

# 4. Boot in QEMU with GDB stub
qemu-system-x86_64 \
  -kernel arch/x86/boot/bzImage \
  -append "root=/dev/sda rw console=ttyS0 nokaslr" \
  -drive file=/tmp/kernel-dev.qcow2,format=qcow2 \
  -nographic -s -S &

# 5. Attach GDB
gdb vmlinux -ex "target remote :1234" -ex "lx-symbols"

# 6. Debug, then repeat
```

> [!tip] Use ccache for faster rebuilds
> Install `ccache` and enable it in the kernel build:
> ```bash
> sudo pacman -S ccache
> export CC="ccache gcc"
> make -j$(nproc)
> ```
> Incremental rebuilds after a small change drop from minutes to seconds.

---

## Gotchas

> [!warning] vmlinux vs bzImage
> GDB needs `vmlinux` (the uncompressed ELF with debug symbols), **not** `bzImage`
> (the compressed boot image). The kernel's build system produces both — always
> pass `vmlinux` to GDB.

> [!warning] KASLR breaks symbol addresses
> If KASLR is enabled, the kernel is loaded at a random virtual address and GDB
> cannot resolve symbols. Always pass `nokaslr` on the kernel command line, or
> disable `CONFIG_RANDOMIZE_BASE` in the config.

> [!warning] GDB Python scripts may be blocked
> Some distributions restrict auto-loading of GDB scripts to known safe
> directories. If GDB refuses to load `vmlinux-gdb.py`, add this to `~/.gdbinit`:
> ```
> add-auto-load-safe-path /path/to/linux/
> ```

> [!warning] Module symbols load dynamically
> Kernel modules are loaded at runtime. Set breakpoints on module functions
> **before** the module is loaded, and use `lx-symbols` after loading to
> resolve the symbols.

> [!tip] Use QEMU monitor for runtime control
> Press `Ctrl+A C` in the QEMU window to access the monitor. Useful commands:
> `info registers`, `info breakpoints`, `gdbserver` (start GDB stub at runtime),
> `quit` (force VM shutdown).

> [!tip] Hardware breakpoints for read-only code
> If `CONFIG_STRICT_KERNEL_RWX` is enabled, software breakpoints won't work on
> read-only kernel text. Use hardware breakpoints (`hbreak`) or disable
> `CONFIG_STRICT_KERNEL_RWX` in your debug config.

---

## Verification

After completing the setup, verify the full workflow:

```bash
# 1. Kernel source is present
ls ~/linux/vmlinux
# Expected: ELF 64-bit LSB executable, x86-64, ... with debug_info

# 2. Debug symbols are embedded
readelf -S ~/linux/vmlinux | grep debug_info
# Expected: [XX] .debug_info PROGBITS ...

# 3. GDB scripts exist
ls ~/linux/vmlinux-gdb.py
# Expected: /home/user/linux/vmlinux-gdb.py

# 4. GDB can load symbols
gdb ~/linux/vmlinux -ex "lx-symbols" -ex "quit"
# Expected: "loading vmlinux" with no errors

# 5. QEMU GDB stub works
qemu-system-x86_64 -kernel ~/linux/arch/x86/boot/bzImage \
  -append "nokaslr" -nographic -s -S &
gdb ~/linux/vmlinux -ex "target remote :1234" -ex "lx-dmesg" -ex "quit"
# Expected: kernel log output from lx-dmesg

# 6. Breakpoints work
gdb ~/linux/vmlinux \
  -ex "target remote :1234" \
  -ex "b start_kernel" \
  -ex "c" \
  -ex "bt" \
  -ex "quit"
# Expected: stack trace showing start_kernel and callers
```

---

## Troubleshooting

### "Remote debugging using :1234" shows `0x0 in ?? ()`

The kernel hasn't started executing yet. Press `c` (continue) in GDB, or remove
`-S` from the QEMU command so the kernel boots immediately.

### `lx-symbols` shows "no modules found"

No kernel modules are loaded yet. Boot the kernel fully, or load a module inside
the VM, then run `lx-symbols` again.

### GDB shows "Function not defined" for module functions

The module isn't loaded yet. Set a pending breakpoint (GDB will ask "Make
breakpoint pending on future shared library load?") and continue. When the module
loads, the breakpoint will activate.

### Build fails with "pahole not found"

Install the `pahole` package (required for BTF generation on recent kernels):

```bash
sudo pacman -S pahole
```

### QEMU fails with "Could not load kernel"

The bzImage may be stale. Rebuild:

```bash
make -j$(nproc)
```

---

## Related

- [[libvirt-virt-manager]] — QEMU/KVM/libvirt setup for running the debug VM
- [[qemu-automated-testing]] — direct QEMU approach for automated kernel testing
- [[arch-setup]] — host machine setup; kernel build tools are part of provisioning
- [[Vault Conventions]] — this note's frontmatter schema and tag taxonomy

---

## Sources

- [Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugging/gdb-kernel-debugging.html) — QEMU GDB stub, lx-* commands, setup
- [Using kgdb, kdb and the kernel debugger internals — Linux Kernel Docs](https://docs.kernel.org/process/debugging/kgdb.html) — KGDB over serial, kdb, kgdboc
- [How to quickly build a trimmed Linux kernel — Linux Kernel Docs](https://docs.kernel.org/admin-guide/quickly-build-trimmed-linux.html) — localmodconfig, debug symbols, build workflow
- [Kdump — kexec-based Crash Dumping Solution — Linux Kernel Docs](https://docs.kernel.org/admin-guide/kdump/kdump.html) — GDB macros for crash dumps, CONFIG_DEBUG_INFO

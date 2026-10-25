---
title: "QEMU/KVM Virtual Machines with GDB Debugging"
aliases:
  - kvm virtual machine debugging
  - qemu gdb debugging
  - virt-manager gdb
  - libvirt debug
  - vm gdb stub
description: >-
  How to create and manage virtual machines with virt/libvirt/QEMU/KVM, and how to
  debug them using GDB (both user-space and kernel-level). Covers VM creation with
  virt-install, GDB stub setup, attaching GDB to running VMs, and kernel debugging
  with lx-* commands and KGDB.
tags:
  - linux
  - qemu
  - kvm
  - virtualization
  - libvirt
  - gdb
  - debugging
  - virt-manager
  - vm
type: guide
status: draft
created: 2026-10-25
updated: 2026-10-25
last_reviewed: 2026-10-25
review_after: 2027-03-27
language: en
audience: sysadmin
scope: creating and debugging QEMU/KVM virtual machines with GDB
platform:
  - Arch Linux
  - Linux
keywords:
  - virt-install
  - virsh
  - qemu-system-x86_64
  - qcow2
  - qemu-img
  - GDB stub
  - target remote
  - lx-symbols
  - lx-dmesg
  - KGDB
  - vmlinux
  - bzImage
  - cloud-init
sources:
  - "[QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU)"
  - "[Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt)"
  - "[Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugging/gdb-kernel-debugging.html)"
  - "[Virt-install — Arch manual pages](https://man.archlinux.org/man/virt-install.1.en)"
source_retrieved: 2026-10-25
related:
  - "[[libvirt-virt-manager]]"
  - "[[libvirt-small-vms]]"
  - "[[qemu-automated-testing]]"
  - "[[kernel-dev-debugging]]"
  - "[[Vault Conventions]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Create a qemu-kvm-vm-debugging note documenting how to create VMs with virt/libvirt and debug with GDB"
ai-review: pending
---

# QEMU/KVM Virtual Machines with GDB Debugging

> [!summary] The one-paragraph answer
> Create a VM with `virt-install` or `virt-manager`, boot it with QEMU listening for a
> GDB stub (`-s` flag), then attach `gdb vmlinux` from the host and use `target remote
> :1234` to debug. For kernel debugging, build the kernel with `CONFIG_DEBUG_INFO`,
> `CONFIG_GDB_SCRIPTS`, and `nokaslr`, then use the kernel's `lx-*` helper commands
> (`lx-symbols`, `lx-dmesg`, `lx-lsmod`) to inspect the running system. The full
> workflow is: provision VM → boot with GDB stub → attach GDB → debug → repeat.

---

## Context

You want to run a Linux guest under QEMU/KVM managed by libvirt, and you need to debug
it with GDB — either user-space applications inside the guest, or the kernel itself.
This note bridges two worlds: **provisioning the VM** (via libvirt/virt-install) and
**attaching a debugger** (via QEMU's GDB stub or KGDB).

See [[libvirt-virt-manager]] for the general libvirt and virt-manager setup, and
[[kernel-dev-debugging.md]] for the complete kernel-development GDB workflow.

---

## Details

### 1. Install required packages

On Arch Linux, install the QEMU/libvirt stack and GDB:

```bash
sudo pacman -S --needed --noconfirm \
  qemu-full \
  libvirt \
  virt-manager \
  virt-install \
  virt-viewer \
  gdb \
  dnsmasq \
  openbsd-netcat
```

| Package | Purpose |
|---|---|
| `qemu-full` | QEMU emulator with full device support |
| `libvirt` | Management daemon (`libvirtd`) and CLI tools (`virsh`) |
| `virt-manager` | GUI frontend for libvirt |
| `virt-install` | CLI tool for creating new VMs |
| `virt-viewer` | SPICE/VNC client for VM displays |
| `gdb` | GNU Debugger — attach to GDB stub or guest process |
| `dnsmasq` | DHCP/DNS for the default NAT network |

Optional but recommended:

```bash
sudo pacman -S --needed --noconfirm \
  qemu-guest-agent \
  bridge-utils \
  openbsd-netcat \
  socat
```

### 2. Start and enable libvirtd

```bash
sudo systemctl start libvirtd.service
sudo systemctl enable libvirtd.service

# Verify
virsh -c qemu:///system list --all
```

Add your user to the `libvirt` group (log out and back in):

```bash
sudo usermod -aG libvirt "$USER"
```

### 3. Create a virtual machine

#### Via virt-install (CLI)

The most common method for creating a VM from an ISO:

```bash
virt-install \
  --name my-vm \
  --memory 4096 \
  --vcpus 2,maxvcpus=4 \
  --cpu host-model \
  --cdrom /var/lib/libvirt/images/archlinux-2026.10.25-x86_64.iso \
  --osinfo detect=on,name=archlinux \
  --disk size=30,format=qcow2 \
  --network network=default \
  --graphics spice \
  --boot uefi \
  --print-xml 2> /dev/null | virsh define --file - \
  --autostart
```

#### Via virt-manager (GUI)

1. Open `virt-manager` (or `virtual-machine-manager`)
2. Click "Create a new virtual machine"
3. Select "Local install media" and browse to your ISO
4. Allocate CPU, RAM, and disk space (qcow2 recommended)
5. Choose networking (default NAT: `virbr0`, or bridge)
6. Select "Customize before install" and check "Boot menu" if needed
7. Click "Begin Installation" — the VM console opens

#### Using cloud-init for headless provisioning

```bash
# Prepare a cloud-iso (see libvirt-small-vms.md §3-4)
virt-install \
  --name cloud-vm \
  --connect qemu:///system \
  --memory 2048 \
  --vcpus 2 \
  --disk path=/var/lib/libvirt/images/cloud-vm.qcow2,format=qcow2 \
  --network network=default \
  --cloud-init user-data="hostname: cloud-vm\npassword: arch\nssh-authorized-key: $(cat ~/.ssh/id_ed25519.pub)" \
  --import \
  --noautoconsole
```

### 4. Boot the VM with a GDB stub

QEMU can listen for a GDB connection on a TCP port. The easiest flag is `-s`, which
is shorthand for `-gdb tcp::1234`.

#### With virt-manager (edit XML)

1. In virt-manager, select the VM → "Details" → "Overview" → "Customize hardware"
2. Or edit the domain XML directly:

```bash
virsh edit my-vm
```

Add (or modify) the `<qemu:commandline>` section:

```xml
<qemu:commandline>
  <qemu:arg value='-s'/>
  <qemu:arg value='-S'/>
</qemu:commandline>
```

Or add directly to `<extra>...</extra>`:

```xml
<extra>
  <arg value='-s'/><arg value='-S'/>
</extra>
```

#### Via virsh edit (recommended)

```bash
virsh edit my-vm
```

Add these lines inside `<domain>...</domain>`:

```xml
<cpu>host-model</cpu>
<features>
  <acpi/>
  <apic/>
</features>
```

Then start the VM:

```bash
virsh start my-vm
```

The `-s` flag makes QEMU listen on `tcp::1234` for a GDB connection.
The `-S` flag freezes the CPU at startup until a GDB client connects.

#### From the command line (direct qemu invocation)

```bash
qemu-system-x86_64 \
  -name my-vm \
  -m 4096 \
  -smp 2 \
  -kernel /usr/share/ovmf/x64/OVMF_CODE.fd \
  -drive file=/var/lib/libvirt/images/my-vm.qcow2,format=qcow2 \
  -netdev user,id=net0,hostfwd=tcp::2222-:22 \
  -device virtio-net,netdev=net0 \
  -nographic -display none \
  -s -S
```

| Flag | Purpose |
|---|---|
| `-s` | GDB stub on port 1234 (shorthand for `-gdb tcp::1234`) |
| `-S` | Freeze CPU at startup — wait for GDB to connect before running |
| `-nographic` | Redirect serial output to stdout (no GUI) |
| `-device virtio-net` | Network device paravirtualized for KVM |

### 5. Attach GDB to the VM

#### User-space debugging (attach to a process inside the guest)

If you just want to debug a running process (e.g. `bash`, `httpd`) inside the VM:

1. **Find the PID** inside the guest:

   ```bash
   # Inside the VM shell (Ctrl+A C to exit, or use virsh console)
   ps aux | grep your-process
   ```

2. **Forward the process** via SSH or port-forwarding:

   ```bash
   # From host, forward guest PID to local port
   ssh -L 1234:127.0.0.1:1234 user@192.168.122.<n>
   ```

   Or use `vncviewer`/`virt-viewer` and attach gdb through the guest's network.

3. **Attach from the host**:

   ```bash
   gdb
   (gdb) attach 127.0.0.1:1234
   ```

   *Note: User-space GDB debugging over a network link is tricky. For best results,
   use `gdbserver` inside the guest, or debug from within the guest using `gdb` directly.*

#### Kernel debugging (QEMU GDB stub)

To debug the Linux kernel running inside the VM:

1. **Build the kernel with debug symbols** (see [[kernel-dev-debugging.md]] §3-4)

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
   make -j$(nproc)
   make scripts_gdb
   ```

2. **Boot the VM with the GDB stub** (via libvirt XML or command line):

   ```bash
   # Using virsh edit to add -s and -S
   virsh start my-vm
   ```

   Or from the command line:

   ```bash
   qemu-system-x86_64 \
     -name my-vm \
     -m 4096 \
     -smp 2 \
     -drive file=/var/lib/libvirt/images/my-vm.qcow2,format=qcow2 \
     -nographic -display none \
     -s -S \
     -append "root=/dev/sda rw nokaslr console=ttyS0" \
     -kernel bzImage  # only if using raw bzImage boot
   ```

   > **Important**: `-s` opens port 1234 for the GDB stub. `-S` freezes the CPU
   > initially. If you omitted `-S`, the kernel boots immediately and you can
   > attach GDB later.

3. **Attach GDB from the host**:

   In a separate terminal:

   ```bash
   gdb vmlinux
   ```

   Inside GDB:

   ```
   (gdb) set auto-load safe on
   (gdb) add-auto-load-safe-path /path/to/linux/
   (gdb) target remote :1234
   (gdb) lx-symbols
   (gdb) lx-dmesg
   ```

   Expected initial output:

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

### 6. Kernel GDB helper commands (lx-*)

The kernel provides Python-based GDB commands when `CONFIG_GDB_SCRIPTS=y`. These are
loaded automatically once `target remote :1234` is established.

| Command | Purpose |
|---|---|
| `lx-symbols` | (Re-)load symbols for vmlinux and all loaded modules |
| `lx-dmesg` | Print the kernel log buffer (dmesg) |
| `lx-lsmod` | List currently loaded kernel modules |
| `lx-current` | Return the current task's `task_struct` |
| `lx-module("name")` | Find a module by name |
| `lx-per_cpu("var")` | Return a per-CPU variable |
| `lx-task_by_pid(PID)` | Find a task by PID |
| `lx-thread_info(TASK)` | Calculate thread_info from a task |

Convenience expressions (usable in GDB commands):

```
(gdb) p $lx_current().pid
(gdb) p $lx_current().comm
(gdb) p $lx_per_cpu(runqueues).nr_running
(gdb) p $lx_module("btrfs")->ops->name
```

### 7. KGDB over serial (alternative to QEMU GDB stub)

For debugging over a physical serial connection or guest serial console:

1. **Kernel command line**:

   ```
   console=ttyS0,115200 kgdboc=ttyS0,115200 nokaslr kgdbwait
   ```

   | Boot argument | Purpose |
   |---|---|
   | `kgdboc=ttyS0,115200` | Route KGDB over the first serial port |
   | `kgdbwait` | Stop at boot and wait for GDB to connect |
   | `nokaslr` | Disable KASLR so symbol addresses match vmlinux |
   | `kgdbcon` | Show `printk` messages inside GDB |

2. **Start GDB on the host**:

   ```bash
   gdb ./vmlinux
   (gdb) set serial baud 115200
   (gdb) target remote /dev/ttyUSB0   # or /dev/ttyS0
   ```

3. **Break into the debugger at runtime**:

   ```
   echo g > /proc/sysrq-trigger
   ```

   Or from the QEMU monitor (`Ctrl+A C`, then `g`).

### 8. The edit-compile-boot-debug loop

The full kernel development cycle using QEMU/KVM + GDB:

```bash
# 1. Edit source code
vim kernel/sched/core.c

# 2. Rebuild (only changed files)
make -j$(nproc) # or: make -j$(nproc) SUBDIR=sound

# 3. Rebuild GDB scripts if needed
make scripts_gdb

# 4. Boot in QEMU with GDB stub
# (via libvirt: virsh start my-vm, or manually with qemu-system-x86_64 -s -S)

# 5. Attach GDB
gdb vmlinux
(gdb) target remote :1234
(gdb) lx-symbols

# 6. Debug
(gdb) b start_kernel
(gdb) c
(gdb) bt       # stack trace
(gdb) p $lx_current().pid
(gdb) c         # continue

# 7. Repeat from step 1
```

> **Tip**: Install `ccache` and set `export CC="ccache gcc"` for incremental rebuilds
> that drop from minutes to seconds.

### 8. Debugging tips and common patterns

#### Set a breakpoint on `start_kernel` and verify the kernel is running

```bash
(gdb) b start_kernel
(gdb) c
```

When the breakpoint hits, you can inspect registers, the task struct, and per-CPU data.

#### Inspect per-CPU variables across all CPUs

```bash
(gdb) watch *$lx_per_cpu(variables).jiffies
```

#### Check if the kernel was built with debug info

```bash
(gdb) q
(readelf -S vmlinux | grep -c debug_info)  # should be > 0
```

#### Use QEMU monitor for runtime control

Press `Ctrl+A C` in the QEMU console to access the monitor. Useful commands:

- `info registers` — dump CPU registers
- `info breakpoints` — list set breakpoints
- `gdbserver` — start/stop GDB stub at runtime
- `quit` — force VM shutdown

#### Debug a loaded kernel module

1. Set a **pending breakpoint** before the module loads:

   ```bash
   (gdb) b btrfs_init_sysfs
   Make breakpoint pending on future shared library load? (y or [n]) y
   ```

2. Continue execution:

   ```bash
   (gdb) c
   ```

3. When the module loads, the breakpoint activates:

   ```bash
   (gdb) lx-symbols
   (gdb) info func btrfs_init_sysfs
   ```

### 9. Troubleshooting

#### "Remote debugging using :1234" shows `0x0 in ?? ()`

The kernel hasn't started executing yet, or GDB connected before the CPU unfroze.

- Remove `-S` from the QEMU command so the kernel boots immediately, then attach:
  ```bash
  (gdb) attach :1234
  ```
- Or press `c` (continue) at the GDB prompt.

#### `lx-symbols` shows "no modules found"

No kernel modules are loaded yet. Boot the kernel fully, or load a module inside
the VM, then run `lx-symbols` again.

#### GDB shows "Function not defined" for module functions

The module isn't loaded yet. Set a pending breakpoint (GDB will ask "Make breakpoint
pending on future shared library load?") and continue. When the module loads, the
breakpoint will activate.

#### QEMU fails with "Could not load kernel"

The bzImage may be stale. Rebuild:

```bash
make -j$(nproc)
```

#### `-s` flag has no effect

Ensure `-S` is also present if you want the CPU to freeze at startup. Without `-S`,
the kernel boots immediately and you must attach GDB after it's running.

### 10. Verification

After completing the setup, verify the full workflow:

```bash
# 1. libvirtd is running
systemctl is-active libvirtd
# Expected: active

# 2. VM appears in virsh
virsh -c qemu:///system list --all
# Expected: my-vm running

# 3. GDB stub is accessible
gdb vmlinux
(gdb) target remote :1234
(gdb) lx-dmesg
# Expected: kernel log output

# 4. Breakpoints work
(gdb) b start_kernel
(gdb) c
# Execution stops at start_kernel

# 5. Module symbols load
(gdb) lx-symbols
# Expected: modules scanned and loaded
```

> [!important] `info kvm` is the check that matters
> Run `virsh qemu-monitor-command my-vm --hmp 'info kvm'` from the host.
> Output should show `kvm support: enabled`. "disabled" means QEMU fell back to
> TCG software emulation — GDB will be slow and symbol addresses will be wrong.

---

## Gotchas

> [!warning] GDB auto-loading blocked by distribution
> Some Linux distributions restrict auto-loading of GDB scripts to "known safe"
> directories. If GDB refuses to load `vmlinux-gdb.py`, add this to `~/.gdbinit`:
> ```
> add-auto-load-safe-path /path/to/linux/
> ```

> [!warning] KASLR breaks symbol addresses
> If KASLR is enabled, the kernel is loaded at a random virtual address and GDB
> cannot resolve symbols. Always pass `nokaslr` on the kernel command line, or
> disable `CONFIG_RANDOMIZE_BASE` in the config.

> [!warning] vmlinux vs bzImage
> GDB needs `vmlinux` (the uncompressed ELF with debug symbols), **not** `bzImage`
> (the compressed boot image). The kernel's build system produces both — always
> pass `vmlinux` to GDB.

> [!warning] Group membership requires re-login
> After `usermod -aG libvirt "$USER"`, you must log out and back in. Group
> membership is evaluated at login time. virt-manager will fail with permission
> errors until you re-authenticate.

> [!warning] `-s` and `-S` must be used together (usually)
> `-s` opens the GDB stub port. `-S` freezes the CPU at startup. If you use only
> `-s`, the kernel boots immediately and you must attach GDB after it's running.
> Use both for the classic "boot-stub-attach" workflow.

> [!warning] Module breakpoints load dynamically
> Kernel modules are loaded at runtime. Set breakpoints on module functions **before**
> the module is loaded, and use `lx-symbols` after loading to resolve the symbols.

> [!tip] Use host-passthrough CPU model for best performance
> In virt-manager: CPU → Copy host CPU configuration. This exposes all host CPU
> features to the guest. Required for nested virtualization.

> [!tip] ccache for faster rebuilds
> Install `ccache` and enable it in the kernel build:
> ```bash
> sudo pacman -S ccache
> export CC="ccache gcc"
> make -j$(nproc)
> ```
> Incremental rebuilds after a small change drop from minutes to seconds.

> [!tip] QEMU monitor for runtime GDB control
> Press `Ctrl+A C` in the QEMU window to access the monitor. From there you can
> start `gdbserver` at runtime, set/clear breakpoints, or force VM shutdown without
> restarting.

> [!tip] Use `virsh qemu-monitor-command` for remote control
> ```bash
> virsh qemu-monitor-command my-vm --hmp 'info registers'
> virsh qemu-monitor-command my-vm --hmp 'gdbserver :1234'
> ```

---

## Related

- [[libvirt-virt-manager]] — QEMU/KVM/libvirt setup for running the debug VM
- [[libvirt-small-vms]] — building minimal-footprint KVM guests
- [[qemu-automated-testing]] — direct QEMU invocation without libverb, for CI pipelines
- [[kernel-dev-debugging]] — full kernel development + GDB debugging workflow
- [[Vault Conventions]] — this note's frontmatter schema and tag taxonomy

---

## Sources

- [QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU) — QEMU package variants,
  KVM enablement, disk images, VirtIO drivers and performance tuning
- [Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt) — daemon setup,
  authentication, storage pools, networking, UEFI and TPM configuration
- [Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugging/gdb-kernel-debugging.html)
  — QEMU GDB stub, lx-* commands, setup
- [Using kgdb, kdb and the kernel debugger internals — Linux Kernel Docs](https://docs.kernel.org/process/debugging/kgdb.html) — KGDB over serial, kdb, kgdboc
- [Virt-install — Arch manual pages](https://man.archlinux.org/man/virt-install.1.en)
  — authoritative option reference: `--memory`, `--disk`, `--network`,
  `--graphics`, `--boot`, `--print-xml`
- [libvirt: Domain XML format](https://libvirt.org/formatdomain.html) — `<qemu:commandline>`,
  `<extra>`, memory tuning, CPU model, `<features>`
- [GDB documentation](https://sourceware.org/gdb/current/onlinedocs/) — `target remote`,
  `lx-*` commands, auto-loading policies

---

## Testing the Kernel in the VM

This section covers **verifying the kernel works correctly** inside the VM after
booting with the GDB stub. Testing ensures your debug configuration is valid,
the kernel functions as expected, and you can actually debug it.

### 9.1 Boot verification (does the kernel start?)

```bash
# From the host, verify the kernel booted with the GDB stub
virsh qemu-monitor-command my-vm --hmp 'info status'

# Expected output (from QEMU monitor):
# status: running

# Or from the GDB perspective:
# After attaching with `target remote :1234`, type `c` to continue
# and verify the kernel is responding:

(gdb) target remote :1234
(gdb) c
# If the kernel is running, GDB will show an address, not `0x0 in ?? ()`
```

### 9.2 Kernel functional basic tests

Run these simple checks to confirm the kernel is operational:

```bash
# Inside the VM (via serial console or SSH if network is up):
# 1. Check CPU info
cat /proc/cpuinfo | head -5

# 2. Check memory
free -h

# 3. Check loaded modules
lsmod | head -10

# 4. Check dmesg (kernel ring buffer)
dmesg | tail -20

# 5. Check process running
ps aux | head -5
```

If using the GDB stub, you can also verify from the host:

```bash
# From GDB, check the current task
(gdb) p $lx_current().pid
# Expected: a PID number (e.g. 1 for init)

# Check dmesg via GDB
(gdb) lx-dmesg
# Expected: kernel boot output
```

### 9.3 Module loading test

Verify kernel modules can be loaded and inspected via GDB:

```bash
# Inside the VM:
modprobe virtio-net
lsmod | grep virtio

# From GDB, after loading a module:
(gdb) lx-lsmod
# Expected: list of loaded modules including virtio-net

# Set a pending breakpoint on a module function, then load the module
(gdb) b btrfs_init_sysfs
Make breakpoint pending on future shared library load? (y or [n]) y
(gdb) c
# Load the module inside the VM:
modprobe btrfs
# GDB will now break at the breakpoint
(gdb) lx-symbols
```

### 9.4 GDB command sanity test

Verify GDB can actually execute kernel helper commands:

```bash
# From GDB prompt after `target remote :1234`:
(gdb) lx-symbols
# Should show "loading vmlinux" and scan for modules

(gdb) lx-dmesg
# Should output kernel boot log (dmesg)

(gdb) lx-lsmod
# Should list loaded modules (may be empty early in boot)

(gdb) p $lx_current().pid
# Should show the PID of the current task (usually 1 early in boot)

(gdb) p $lx_per_cpu(runqueues).nr_running
# Should show per-CPU runqueue state
```

If any of these fail:
- Ensure `CONFIG_GDB_SCRIPTS=y` is set in the kernel config
- Ensure `vmlinux` (not `bzImage`) is being used
- Ensure `-s -S` flags are used when booting QEMU
- Ensure `nokaslr` is on the kernel command line

### 9.5 Performance basic check

Verify the VM is using KVM acceleration (not TCG software emulation):

```bash
# From the host via virsh monitor
virsh qemu-monitor-command my-vm --hmp 'info kvm'

# Expected output:
# kvm support: enabled

# If "disabled", QEMU fell back to TCG emulation:
# - GDB will be extremely slow
# - Symbol addresses will be wrong
# - Re-enable KVM: ensure /dev/kvm exists, user is in kvm group,
#   and QEMU was started with -enable-kvm
```

### 9.6 Stress test (brief)

Run a quick workload to confirm the kernel doesn't crash:

```bash
# Inside the VM:
yes "" | head -1000 > /dev/null
cpu_load=$(cat /proc/load_average | cut -d' ' -f1)
echo "Current load: $cpu_load"

# Or run a brief build:
make -j4 2>&1 | tail -5
# Expected: build completes without kernel panic
```

---

### 10. Troubleshooting Testing

#### Testing fails: "Remote debugging using :1234" shows `0x0 in ?? ()`

The kernel hasn't started executing, or GDB connected before the CPU unfroze.

- Remove `-S` from QEMU command so the kernel boots immediately, then attach:
  ```bash
  (gdb) attach :1234
  ```
- Or press `c` (continue) at the GDB prompt.

#### `lx-symbols` shows "no modules found"

No kernel modules are loaded yet. Boot the kernel fully, or load a module inside
the VM, then run `lx-symbols` again.

#### GDB shows "Function not defined" for module functions

The module isn't loaded yet. Set a pending breakpoint (GDB will ask "Make breakpoint
pending on future shared library load?") and continue. When the module loads, the
breakpoint will activate.

#### QEMU kvm support: disabled

Run `virsh qemu-monitor-command my-vm --hmp 'info kvm'`. If disabled:
- Ensure `/dev/kvm` exists and has correct permissions
- Ensure your user is in the `kvm` group (log out and back in)
- Add `-enable-kvm` to the QEMU command line

#### Kernel panics during testing

- Verify `nokaslr` is on the kernel command line
- Ensure the kernel config has `CONFIG_DEBUG_INFO` and `CONFIG_FRAME_POINTER`
- Check `dmesg` inside the VM for the panic cause
- Try booting without the GDB stub (`-S` removed) to see if the panic is GDB-related

---

## Verification

After completing the setup, verify the full workflow:

```bash
# 1. libvirtd is running
systemctl is-active libvirtd
# Expected: active

# 2. VM appears in virsh
virsh -c qemu:///system list --all
# Expected: my-vm running

# 3. GDB stub is accessible
gdb vmlinux
(gdb) target remote :1234
(gdb) lx-dmesg
# Expected: kernel log output

# 4. Breakpoints work
(gdb) b start_kernel
(gdb) c
# Execution stops at start_kernel

# 5. Module symbols load
(gdb) lx-symbols
# Expected: modules scanned and loaded

# 6. KVM acceleration confirmed
virsh qemu-monitor-command my-vm --hmp 'info kvm'
# Expected: kvm support: enabled
```

> [!important] `info kvm` is the check that matters
> Run `virsh qemu-monitor-command my-vm --hmp 'info kvm'` from the host.
> Output should show `kvm support: enabled`. "disabled" means QEMU fell back to
> TCG software emulation. Everything else in this note assumes KVM. A GUI console
> that feels unbearably slow is almost always this.

---

## Related

- [[libvirt-virt-manager]] — QEMU/KVM/libvirt setup for running the debug VM
- [[libvirt-small-vms]] — building minimal-footprint KVM guests
- [[qemu-automated-testing]] — direct QEMU invocation without libvirt, for CI pipelines
- [[kernel-dev-debugging]] — full kernel development + GDB debugging workflow
- [[Vault Conventions]] — this note's frontmatter schema and tag taxonomy

---

## Sources

- [QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU) — QEMU package variants,
  KVM enablement, disk images, VirtIO drivers and performance tuning
- [Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt) — daemon setup,
  authentication, storage pools, networking, UEFI and TPM configuration
- [Debugging kernel and modules via gdb — Linux Kernel Docs](https://docs.kernel.org/process/debugbing/gdb-kernel-debugging.html)
  — QEMU GDB stub, lx-* commands, setup
- [Using kgdb, kdb and the kernel debugger internals — Linux Kernel Docs](https://docs.kernel.org/process/debugging/kgdb.html) — KGDB over serial, kdb, kgdboc
- [Virt-install — Arch manual pages](https://man.archlinux.org/man/virt-install.1.en)
  — authoritative option reference: `--memory`, `--disk`, `--network`,
  `--graphics`, `--boot`, `--print-xml`
- [Kernel Self-Test (kselftest) — Linux Kernel Docs](https://docs.kernel.org/developers/kselftest.html)
  — kernel self-test framework
- [libvirt: Domain XML format](https://libvirt.org/formatdomain.html) — `<qemu:commandline>`,
  `<extra>`, memory tuning, CPU model, `<features>`
- [GDB documentation](https://sourceware.org/gdb/current/onlinedocs/) — `target remote`,
  `lx-*` commands, auto-loading policies
- [QEMU monitor command reference](://qemu.org/docs/master/system/monitor.html) — `info kvm`,
  `info status`, `gdbserver`, monitor commands
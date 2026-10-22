---
title: "Libvirt & Virt-Manager with QEMU/KVM on Arch Linux"
aliases:
  - libvirt setup
  - virt-manager setup
  - QEMU KVM Arch
  - KVM virtualization
  - libvirtd
  - virt-manager guide
  - QEMU libvirt
description: >-
  Complete guide to installing and configuring libvirt, virt-manager, and QEMU/KVM on
  Arch Linux: package installation, KVM verification, libvirtd daemon setup, polkit
  authentication, storage pools, networking (NAT/bridged), UEFI/TPM support, and
  troubleshooting common errors.
tags:
  - arch-linux
  - libvirt
  - qemu
  - virtualization
  - kvm
  - virt-manager
  - networking
  - guide
type: guide
status: draft
created: 2026-09-28
updated: 2026-09-28
last_reviewed: 2026-09-28
review_after: 2027-03-28
language: en
audience: sysadmin
scope: host-side libvirt/QEMU/KVM setup with virt-manager GUI
platform:
  - Arch Linux
  - Linux
keywords:
  - libvirtd
  - virt-manager
  - virt-install
  - virsh
  - qemu-system-x86_64
  - /dev/kvm
  - polkit
  - OVMF
  - swtpm
  - virtio
  - qcow2
  - NAT
  - bridged networking
  - UEFI
  - TPM 2.0
  - Secure Boot
  - dnsmasq
  - virt-viewer
  - SPICE
sources:
  - "[Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt)"
  - "[Virt-manager — ArchWiki](https://wiki.archlinux.org/title/Virt-manager)"
  - "[QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU)"
  - "[KVM — ArchWiki](https://wiki.archlinux.org/title/KVM)"
source_retrieved: 2026-09-28
related:
  - "[[arch-setup]]"
  - "[[qemu-automated-testing]]"
  - "[[libvirt-small-vms]]"
  - "[[Vault Conventions]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document libvirt and virt-manager setup"
ai-review: pending
---

# Libvirt & Virt-Manager with QEMU/KVM on Arch Linux

> [!summary] The one-paragraph answer
> Install `qemu-full`, `libvirt`, `virt-manager`, and `edk2-ovmf` from pacman. Verify KVM
> hardware support, load kernel modules, start `libvirtd.service`, add your user to the
> `libvirt` group, and launch virt-manager. The default NAT network (`virbr0`) works
> out of the box for most use cases. For UEFI guests, use OVMF; for Windows 11, add
> `swtpm` for TPM 2.0 emulation. Storage lives in `/var/lib/libvirt/images/` by default;
> use qcow2 format for snapshots and copy-on-write efficiency.

---

## Context

You want to run virtual machines on Arch Linux with hardware acceleration. QEMU provides
the emulation, KVM provides the kernel-level virtualization backend for near-native
performance, and libvirt provides the management layer (daemon, API, CLI tools). virt-manager
is the GUI frontend for libvirt.

This guide covers the **system-level** setup (libvirtd running as root, VMs run as
`libvirt-qemu` user). This is the recommended mode for desktop use: it supports autostart,
bridged networking, and proper permission handling. The alternative — `qemu:///session` —
runs everything as your user but has limited networking (SLIRP only, no bridge).

See [[qemu-automated-testing]] for a direct-QEMU approach without libvirt, useful for
headless CI pipelines. See [[libvirt-small-vms]] for the opposite question — how to make
the VMs this guide creates as small as possible.

---

## Details

### 1. Verify KVM hardware support

Before installing anything, confirm your CPU supports virtualization and the kernel
modules are available:

```bash
# Check CPU virtualization support
LC_ALL=C.UTF-8 lscpu | grep Virtualization
# Expected: "Virtualization: VT-x" (Intel) or "Virtualization: AMD-V" (AMD)

# Check kernel config
zgrep CONFIG_KVM= /proc/config.gz
# Should show CONFIG_KVM=y or CONFIG_KVM=m, plus CONFIG_KVM_INTEL or CONFIG_KVM_AMD

# Check if modules are loaded
lsmod | grep kvm
# Expected: kvm_intel or kvm_amd, plus kvm
```

If `/dev/kvm` does not exist, enable virtualization in BIOS/UEFI (often called
"Intel VT-x", "AMD-V", "SVM Mode", or "Virtualization Technology").

> [!warning] Laptop BIOS gotcha
> Many laptop manufacturers ship with virtualization disabled by default. If `lscpu`
> shows no virtualization flag, reboot into BIOS/UEFI and enable it before proceeding.

### 2. Install packages

```bash
sudo pacman -S --needed --noconfirm \
  qemu-full \
  libvirt \
  virt-manager \
  virt-install \
  virt-viewer \
  edk2-ovmf \
  swtpm \
  dnsmasq \
  openbsd-netcat
```

| Package | Purpose |
|---|---|
| `qemu-full` | QEMU emulator with all architectures and GUI support |
| `libvirt` | Management layer: daemon (`libvirtd`), API, `virsh` CLI |
| `virt-manager` | GUI frontend for libvirt |
| `virt-install` | CLI tool for creating new VMs |
| `virt-viewer` | SPICE/VNC client for connecting to VM displays |
| `edk2-ovmf` | UEFI firmware for VMs (OVMF) |
| `swtpm` | Software TPM emulation (required for Windows 11) |
| `dnsmasq` | DHCP/DNS for the default NAT network |
| `openbsd-netcat` | Remote management over SSH |

Optional but recommended:

```bash
sudo pacman -S --needed --noconfirm \
  qemu-guest-agent \
  dmidecode \
  libvirt-python
```

#### QEMU package variants

Arch Linux ships QEMU as a split package with three meta-packages. All three provide
the same `qemu-system-x86_64` binary — they differ in what additional emulators,
drivers, and UI backends they pull in:

| Variant | Description | Use when |
|---|---|---|
| `qemu-full` | Everything: all system emulators (x86, ARM, PPC, RISC-V, etc.), all audio backends, all display drivers, USB redirect, iSCSI, docs, tests | Desktop use, cross-architecture emulation, maximum compatibility |
| `qemu-desktop` | x86_64 system emulator + desktop-oriented drivers (GTK, SDL, SPICE, audio, USB, VirtIO GPU) | Desktop virtualization with virt-manager — the lightest full-desktop option |
| `qemu-base` | x86_64 system emulator only, headless, no GUI backends | Servers, CI pipelines, headless VMs, minimal disk footprint |

All three depend on the same base packages (`qemu-common`, `qemu-img`,
`qemu-system-x86`, `virtiofsd`). The difference is in the optional dependencies
they pull in:

- **`qemu-full`** adds: `qemu-emulators-full` (ARM, PPC, RISC-V, etc.), all audio
  drivers (ALSA, PulseAudio, JACK, OSS, SDL, D-Bus, SPICE), `qemu-user` (usermode
  emulation), `qemu-user-static`, `qemu-docs`, `qemu-tests`, `qemu-tools`,
  `qemu-pr-helper`, `qemu-vmsr-helper`, `samba` (optional)
- **`qemu-desktop`** adds: GTK/SDL/OpenGL/EGL/curses/D-Bus UI drivers, SPICE app,
  audio drivers (ALSA, PulseAudio, PipeWire, JACK, OSS, SDL, D-Bus, SPICE), USB
  redirect, block drivers (curl, DMG, NFS, SSH), VirtIO GPU display, QXL, UEFI vars
- **`qemu-base`** adds: nothing beyond the base — just `qemu-system-x86_64` and
  `qemu-img`

> [!tip] Which to choose for virt-manager?
> `qemu-desktop` is the sweet spot for desktop virtualization with virt-manager. It
> includes all the display, audio, and USB drivers you need without the overhead of
> cross-architecture emulators. `qemu-full` is only needed if you emulate non-x86
> architectures (e.g. ARM, RISC-V). `qemu-base` is for headless servers where you
> never attach a graphical console.

#### What `qemu-full` actually installs

`qemu-full` (version 11.1.1-4 on Arch) is a meta-package that pulls in **87
dependencies**. Here is the full breakdown by category:

**Core system emulators** (via `qemu-emulators-full`):
- `qemu-system-x86_64` / `qemu-system-i386` — x86 64-bit and 32-bit
- `qemu-system-aarch64` — ARM 64-bit
- `qemu-system-arm` — ARM 32-bit
- `qemu-system-ppc` / `qemu-system-ppc64` — PowerPC 32/64-bit
- `qemu-system-riscv32` / `qemu-system-riscv64` — RISC-V 32/64-bit
- `qemu-system-s390x` — IBM System z
- `qemu-system-sparc` / `qemu-system-sparc64` — Sun SPARC
- `qemu-system-mips` / `qemu-system-mips64` — MIPS
- `qemu-system-m68k` — Motorola 68000 (ColdFire)
- `qemu-system-alpha` — DEC Alpha
- `qemu-system-hppa` — HP PA-RISC
- `qemu-system-sh4` — Renesas SuperH
- `qemu-system-xtensa` — Cadence Xtensa
- `qemu-system-or1k` — OpenRISC 32-bit
- `qemu-system-avr` — Atmel AVR (MCU)
- `qemu-system-hexagon` — Qualcomm Hexagon (DSP)
- `qemu-system-tricore` — Infineon TriCore
- `qemu-system-rx` — Renesas RX

**User-mode emulation**:
- `qemu-user` — run Linux binaries from other architectures as regular processes
- `qemu-user-static` — statically-linked version, usable in chroots/containers

**Audio backends**:
- `qemu-audio-alsa` — ALSA
- `qemu-audio-pa` — PulseAudio
- `qemu-audio-jack` — JACK
- `qemu-audio-oss` — Open Sound System
- `qemu-audio-sdl` — SDL audio
- `qemu-audio-spice` — SPICE audio
- `qemu-audio-dbus` — D-Bus audio
- `qemu-audio-pipewire` — PipeWire

**Display drivers** (via `qemu-desktop`):
- `qemu-hw-display-qxl` — QXL (legacy VirtIO)
- `qemu-hw-display-virtio-gpu` / `-gl` / `-pci` / `-pci-gl` — VirtIO GPU
- `qemu-hw-display-virtio-vga` / `-gl` — VirtIO VGA
- `qemu-hw-display-virtio-gpu-rutabaga` — Rutabaga GPU virtualization
- `qemu-ui-gtk` — GTK window
- `qemu-ui-sdl` — SDL window
- `qemu-ui-opengl` — OpenGL rendering
- `qemu-ui-egl-headless` — Headless EGL
- `qemu-ui-curses` — Text-mode curses UI
- `qemu-ui-spice-app` / `qemu-ui-spice-core` — SPICE protocol
- `qemu-ui-dbus` — D-Bus UI
- `qemu-vhost-user-gpu` — vhost-user GPU passthrough

**Block/storage drivers**:
- `qemu-block-curl` — HTTP/HTTPS via libcurl
- `qemu-block-dmg` — Apple DMG images
- `qemu-block-nfs` — NFS shares
- `qemu-block-ssh` — SSH/SFTP
- `qemu-block-iscsi` — iSCSI targets

**USB support**:
- `qemu-hw-usb-host` — USB host device passthrough
- `qemu-hw-usb-redirect` — USB redirection over network
- `qemu-hw-usb-smartcard` — USB smartcard reader

**UEFI support**:
- `qemu-hw-uefi-vars` — UEFI variable store (NVRAM)

**Networking helpers**:
- `qemu-pr-helper` — persistent reservation helper for shared storage
- `qemu-vmsr-helper` — RAPL MSR access for power monitoring

**Tools and tests**:
- `qemu-tools` — `qemu-io`, `qemu-nbd`, `qemu-fsfreeze`, etc.
- `qemu-docs` — full documentation
- `qemu-tests` — QEMU test suite

**Optional**:
- `samba` — enables QEMU's built-in SMB server (`-nic user,smb=...`)
- `qemu-user-static` — for static usermode emulation

### 3. Start and enable libvirtd

```bash
# Start the daemon
sudo systemctl start libvirtd.service

# Enable at boot (also enables virtlogd.socket and virtlockd.socket)
sudo systemctl enable libvirtd.service

# Verify
systemctl status libvirtd.service
```

For on-demand socket activation instead of a always-running daemon:

```bash
sudo systemctl enable --now libvirtd.socket
sudo systemctl enable --now virtlogd.socket
```

> [!note] Modular daemons
> Libvirt is transitioning from a monolithic `libvirtd` to modular daemons
> (`virtqemud`, `virtlxcd`, etc.). The modular `virtqemud.socket` can be enabled
> instead of `libvirtd.socket`. Modular and monolithic daemons cannot run
> simultaneously.

### 4. Configure authentication

#### Option A: libvirt group (simplest)

```bash
sudo usermod -aG libvirt "$USER"
# Log out and back in for group membership to take effect
```

Members of the `libvirt` group get password-less access to the libvirt daemon socket.

#### Option B: polkit (default)

Libvirt uses polkit by default. If your user is in the `wheel` group (Arch default),
you will be prompted for your password when connecting via virt-manager. No additional
configuration needed.

To create a custom group with password-less access:

```bash
# /etc/polkit-1/rules.d/50-libvirt.rules
polkit.addRule(function(action, subject) {
    if (action.id == "org.libvirt.unix.manage" &&
        subject.isInGroup("mykvm")) {
            return polkit.Result.YES;
    }
});
```

```bash
sudo usermod -aG mykvm "$USER"
# Log out and back in
```

### 5. Verify the installation

```bash
# Test system-level connection
virsh -c qemu:///system

# Inside virsh shell:
virsh # list --all
virsh # uri
virsh # quit
```

Expected output:

```text
 Id   Name   State
--------------------
```

### 6. Launch virt-manager

```bash
virt-manager
```

The first launch will prompt you to connect to "QEMU/KVM system" — click Connect.
You should see the default NAT network (`default`) and the default storage pool
(`default`).

### 7. Storage pools

The default pool is at `/var/lib/libvirt/images/`. To create a custom pool:

```bash
# Create a directory for VM disks
sudo mkdir -p /var/lib/libvirt/images/vm-disks
sudo chown -R libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/vm-disks

# Define and start a new pool
virsh pool-define-as vm-disks dir - - - - /var/lib/libvirt/images/vm-disks
virsh pool-build vm-disks
virsh pool-start vm-disks
virsh pool-autostart vm-disks
```

Or via virt-manager: Edit → Connection Details → Storage → + (Add Pool).

### 8. Networking

#### NAT (default)

The `default` network uses NAT with DHCP via dnsmasq. VMs get IPs in `192.168.122.0/24`.
This works out of the box — no configuration needed.

```bash
# Verify the default network is active
virsh net-list --all
virsh net-dhcp-leases default
```

#### Bridged networking

For VMs that need to appear as independent devices on your LAN:

```bash
# Create a bridge interface
sudo ip link add name br0 type bridge
sudo ip link set br0 up
sudo ip link set eth0 master br0   # replace eth0 with your physical interface

# In virt-manager: Edit → Connection Details → Virtual Networks → +
# Select "Bridge" mode and choose br0
```

> [!warning] Bridge + NetworkManager
> If you use NetworkManager, create the bridge via `nmcli` or the NM GUI instead of
> raw `ip` commands, so the bridge survives reboots.

### 9. Create a virtual machine

#### Via virt-manager (GUI)

1. Click "Create a new virtual machine"
2. Select "Local install media" and browse to your ISO
3. Allocate CPU and RAM
4. Create or select a disk image (qcow2 recommended)
5. Select the network (default NAT or bridge)
6. Click Finish — the VM console opens automatically

#### Via virt-install (CLI)

```bash
virt-install \
  --name arch-linux \
  --memory 4096 \
  --vcpus=2,maxvcpus=4 \
  --cpu host-model \
  --cdrom /home/user/Downloads/archlinux-2026.09.01-x86_64.iso \
  --osinfo detect=on,name=archlinux \
  --disk size=30,format=qcow2 \
  --network network=default \
  --virt-type kvm \
  --graphics spice
```

### 10. UEFI support

For UEFI guests (required for Windows 11, recommended for modern Linux):

```bash
# In virt-manager: VM Details → Overview → Firmware → UEFI
# Or via virsh edit:
<os firmware='efi'>
  <loader readonly='yes' type='pflash'>/usr/share/edk2/x64/OVMF_CODE.4m.fd</loader>
  <nvram template='/usr/share/edk2/x64/OVMF_VARS.4m.fd'>/var/lib/libvirt/qemu/nvram/vm_name_VARS.fd</nvram>
</os>
```

### 11. TPM 2.0 emulation (Windows 11)

Windows 11 requires TPM 2.0. Use `swtpm`:

```bash
# Start swtpm daemon
swtpm socket --tpm2 --tpmstate dir=/var/lib/libvirt/swtpm/vm-name \
  --ctrl type=unixio,path=/var/lib/libvirt/swtpm/vm-name/swtpm-sock

# In virt-manager: Add Hardware → TPM → Type: Emulator, Model: TIS, Version: 2.0
# Or via virsh edit:
<devices>
  <tpm model='tpm-tis'>
    <backend type='emulator' version='2.0'/>
  </tpm>
</devices>
```

### 12. SPICE for display and input

SPICE provides the best desktop experience (clipboard sharing, USB redirection,
dynamic resolution):

```bash
# In virt-manager: Display → Type: SPICE
# Connect with:
virt-viewer --connect qemu:///system vm-name
```

Install SPICE guest tools in the guest for full functionality:
- Linux: `spice-vdagent` package
- Windows: [SPICE Guest Tools](https://www.spice-space.org/download.html)

### 13. VirtIO drivers for performance

For best disk and network performance, use VirtIO devices:

- **Disk**: Bus → VirtIO (requires `virtio` driver in guest)
- **Network**: Device model → virtio
- **Display**: Virtio with 3D acceleration (for Linux guests with Mesa)

For Windows guests, download [VirtIO drivers](https://github.com/virtio-win/virtio-win-pkg-scripts/blob/master/README.md)
and attach the ISO during installation.

---

## Gotchas

> [!warning] Group membership requires re-login
> After `usermod -aG libvirt "$USER"`, you must log out and back in. Group membership
> is evaluated at login time. virt-manager will fail with permission errors until you
> re-authenticate.

> [!warning] libvirtd and modular daemons conflict
> Do not enable both `libvirtd.service` and `virtqemud.socket` — they conflict. Pick
> one mode and stick with it.

> [!warning] qcow2 on Btrfs — disable CoW
> If storing VM disks on Btrfs, disable copy-on-write for the images directory:
> ```bash
> sudo chattr +C /var/lib/libvirt/images/vm-disks
> ```
> Without this, qcow2 performance degrades significantly due to nested CoW.

> [!warning] Windows 11 requires UEFI + TPM 2.0
> Windows 11 will not install in BIOS mode. You must enable UEFI firmware and TPM 2.0
> in the VM settings before installation.

> [!warning] NAT blocks inbound connections
> The default NAT network blocks inbound connections from the host to the guest. For
> inbound access, use bridged networking or port forwarding.

> [!tip] Use host-passthrough CPU model for best performance
> In virt-manager: CPU → Copy host CPU configuration. This exposes all host CPU
> features to the guest. Required for nested virtualization.

> [!tip] qcow2 vs raw
> qcow2: sparse allocation, snapshots, compression. Raw: maximum performance, no
> snapshots. For desktop use, qcow2 is the right default.

---

## Verification

After completing the setup, verify everything works:

```bash
# 1. libvirtd is running
systemctl is-active libvirtd
# Expected: active

# 2. KVM is accessible
ls -la /dev/kvm
# Expected: crw-rw---- 1 root kvm

# 3. Default network is active
virsh net-list --all
# Expected: default    active    yes

# 4. Default pool is active
virsh pool-list --all
# Expected: default    active    yes

# 5. Can connect to system URI
virsh -c qemu:///system list --all
# Expected: (empty list, no error)

# 6. Create a test VM and boot it
virt-install --name test-vm --memory 1024 --vcpus 1 \
  --disk size=5,format=qcow2 --network network=default \
  --osinfo detect=on,name=archlinux --cdrom /path/to/archlinux.iso \
  --graphics spice --noautoconsole

# 7. Check VM is running
virsh list --all

# 8. Connect to display
virt-viewer --connect qemu:///system test-vm

# 9. Clean up
virsh destroy test-vm
virsh undefine test-vm --remove-all-storage
```

---

## Troubleshooting

### "Permission denied" accessing /dev/kvm

```bash
# Add user to kvm group
sudo usermod -aG kvm "$USER"
# Log out and back in
```

### "Network 'default' is not active"

```bash
virsh net-start default
virsh net-autostart default
```

### "Virt Manager doesn't have search permissions"

Your user is not in the `libvirt` group, or you have not re-logged in after adding
the group. Verify with `groups` and re-login if needed.

### "Requested operation is not valid: network 'default' is not active"

Same as above — the default network is not started. Run `virsh net-start default`.

### No network connectivity in VM

If using NAT with nftables, ensure forwarding is allowed:

```bash
# /etc/nftables.conf
table inet filter {
  chain forward {
    type filter hook forward priority filter
    policy drop
    iifname virbr0 accept
    oifname virbr0 accept
  }
}
```

### VM boots but no display

- Ensure SPICE or VNC is selected in VM settings
- Check that `virt-viewer` is installed
- For headless servers, use `-nographic` or VNC instead of SPICE

### Windows VM blue screens on boot

- Ensure KVM acceleration is enabled (`-accel kvm` / `--virt-type kvm`)
- For Windows 7/8, KVM is required — without it, Windows BSODs
- Install VirtIO drivers during Windows setup (attach the VirtIO ISO as a second CD)

---

## Related

- [[arch-setup]] — host machine setup; libvirt is part of the provisioning
- [[qemu-automated-testing]] — direct QEMU approach without libvirt, for CI pipelines
- [[libvirt-small-vms]] — trimming the footprint: headless QEMU variants, a 512 MiB /
  1 vCPU guest, virtio-everything device budgets, cloud-init instead of an installer,
  and qcow2 overlays
- [[Vault Conventions]] — this note's frontmatter schema and tag taxonomy

---

## Sources

- [Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt) — daemon setup, authentication, networking, storage
- [Virt-manager — ArchWiki](https://wiki.archlinux.org/title/Virt-manager) — GUI configuration, 3D acceleration
- [QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU) — KVM enabling, disk images, VirtIO drivers
- [KVM — ArchWiki](https://wiki.archlinux.org/title/KVM) — hardware verification, nested virtualization, hugepages

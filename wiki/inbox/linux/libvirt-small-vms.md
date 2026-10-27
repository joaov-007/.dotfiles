---
title: "Small Virtual Machines with QEMU and libvirt"
aliases:
  - small VMs
  - libvirt minimal VMs
  - tiny VMs
  - lightweight virtualization
description: >-
  How to build deliberately small virtual machines with QEMU and libvirt on Arch Linux:
  a host-side footprint budget (which QEMU package variant), a guest-side device
  budget (virtio everything, no VGA, no USB, no audio), a 512 MiB / 1 vCPU
  baseline, cloud-init provisioning instead of an installer, passt networking
  without root, and copy-on-write overlays so each VM costs only its delta.
tags:
  - libvirt
  - qemu
  - virtualization
  - kvm
  - networking
  - performance
  - resource-limits
  - provisioning
  - storage
  - uefi
categories: linux
type: guide
status: draft
created: 2026-10-22
updated: 2026-10-22
last_reviewed: 2026-10-22
review_after: 2026-11-22
language: en
audience: sysadmin
scope: >-
  Building minimal-footprint KVM guests with libvirt and virt-install on Arch
  Linux — host package selection, guest device budget, provisioning, networking
  and copy-on-write storage.
platform:
  - Arch Linux
  - Linux
keywords:
  - virt-install
  - virsh
  - qemu-system-x86_64
  - qcow2
  - cloud-init
  - NoCloud
  - passt
  - virtio-rng
  - pvspinlock
  - memballoon
  - backing file
  - transient domain
  - --print-xml
  - --dry-run
  - swtpm
  - edk2-ovmf
sources:
  - "[Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt)"
  - "[QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU)"
  - "[QEMU/Troubleshooting — ArchWiki](https://wiki.archlinux.org/title/QEMU/Troubleshooting)"
  - "[KVM — ArchWiki](https://wiki.archlinux.org/title/KVM)"
  - "[virt-install(1) — Arch manual pages](https://man.archlinux.org/man/virt-install.1.en)"
  - "[libvirt: Domain XML format](https://libvirt.org/formatdomain.html)"
  - "[libvirt: Network XML format](https://libvirt.org/formatnetwork.html)"
  - "[Arch Linux generic cloud images](https://geo.mirror.pkgbuild.com/images/latest/)"
  - "[OpenStack Virtual Machine Image Guide — Get images](https://docs.openstack.org/image-guide/obtain-images.html)"
source_retrieved: 2026-10-22
related:
  - "[[libvirt-virt-manager]]"
  - "[[qemu-automated-testing]]"
  - "[[arch-setup]]"
  - "[[Vault Conventions]]"
cssclasses:
  - nota-longa
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Create a libvirt-small-vms note documenting how to build small-footprint QEMU/libvirt VMs on Arch Linux"
ai-review: pending
---

# Small Virtual Machines with QEMU and libvirt

> [!summary] The one-paragraph answer
> "Small" is two budgets, not one. On the **host**, install `qemu-base` (headless,
> no GTK/SPICE) instead of `qemu-full`: the whole QEMU package set is 70 MiB, and
> `qemu-full` would be 716 MiB plus 641 MiB of emulators nobody uses. On the
> **guest**, start from 512 MiB RAM and 1 vCPU, put every device on virtio, drop
> the video card (`--video none`), drop USB (`--controller type=usb,model=none`),
> drop the audio codec, and add `--rng /dev/urandom` so a headless guest does not
> stall on entropy at boot. Skip the installer entirely: boot a cloud image with
> `--cloud-init`, and give each VM a qcow2 **overlay** so the pristine base image
> stays untouched and every VM costs only its own delta. Use `--dry-run
> --print-xml` before anything touches disk. The one trap that will bite a Linux
> guest: Arch's `edk2-ovmf` ≥ 202505-1 breaks GRUB in UEFI mode — stay on SeaBIOS
> unless you are installing Windows 11.

---

## Context

[[libvirt-virt-manager]] covers the general setup: daemon, authentication, storage
pools, bridged networking, UEFI, TPM. This note is the opposite question — how do
you make a VM that *costs as little as possible* while still being a real,
maintainable guest.

Two failure modes to avoid:

- **Small but slow.** A 512 MiB guest without virtio devices, with TCG
  emulation instead of KVM, and with `cache=writethrough` on a spinning-disk
  image is slower than a fat VM with virtio and KVM. Footprint and speed are
  different axes.
- **Small but fragile.** Headless guests that hang on entropy, guests that
  cannot be shut down cleanly, guests that need a human to type at the console.
  Everything removed has to be replaced by something else — usually
  cloud-init plus `qemu-guest-agent`.

This note targets **Linux** guests. Windows 11 has hard requirements (UEFI,
TPM 2.0, VirtIO drivers) that blow the budget; those are covered in §6.

Target versions: `libvirt` 12.8.0, `virt-install` 5.1.0, `qemu` 11.1.2,
`edk2-ovmf` 202608-1.

---

## Details

### 1. Decide the two budgets

**Host budget** — which QEMU variant to install. Measured from the Arch
repository at `qemu` 11.1.2-1:

| Variant | QEMU packages | QEMU footprint | Marginal cost | Use when |
|---|---|---|---|---|
| `qemu-base` | 5 | **70.4 MiB** | — | headless guests, SSH-only, CI |
| `qemu-desktop` | 42 | **74.4 MiB** | +696 MiB of GTK/SDL/Mesa/LLVM/pipewire | you want `virt-manager` / `virt-viewer` consoles |
| `qemu-full` | 80 | **715.6 MiB** | +641 MiB of other architectures and `qemu-user` | you emulate non-x86 guests |

The 70 MiB floor is `qemu-system-x86` (55.0), `qemu-img` (10.7),
`qemu-common` (4.5), `virtiofsd` (2.4) and the 48 KiB meta-package. The
`desktop` and `full` variants are **cumulative** — `qemu-desktop` depends on
`qemu-base` and `qemu-full` depends on `qemu-desktop`, so you can add one on
top of the other at any time without uninstalling anything.

The desktop delta is the graphics stack, not QEMU: `mesa` (54), `llvm-libs`
(165), `gtk3` (53), the 32-bit twins of mesa and LLVM (224) and `icu` (43) all
come along. On a host that already runs a desktop you have most of it anyway;
on a headless server it is the single largest line in the budget.

> [!tip] `qemu-base` still gives you `qemu-img`
> You need `qemu-img` for overlays and for `qemu-img info`. `qemu-base` includes it.

> [!warning] `qemu-base` has no graphical console
> `virt-manager` and `virt-viewer` need the `qemu-ui-*` and `qemu-hw-display-*`
> packages, which arrive with `qemu-desktop`. Without them you get a serial
> console and `virsh console` only.

**Guest budget** — the device set:

| Resource | Small value | Floor | Notes |
|---|---|---|---|
| RAM | 512 MiB | 512 MiB | 128 MiB is the QEMU default and will not boot a Linux distro |
| vCPU | 1 | 1 | leave a physical core for the host |
| Disk | 2 GiB qcow2 (the cloud image's own size) | 2 GiB | ~1.5 GiB real for the image, plus only the delta once it runs |
| Firmware | SeaBIOS (BIOS) | SeaBIOS | smaller and faster than UEFI; see §7 |
| Video | none | none | `--video none` |
| USB | none | none | `--controller type=usb,model=none` |
| Audio | none | none | omit the `--audio`/sound device entirely |
| Input | none | none | no tablet, no PS/2 mouse |
| NIC | virtio-net | virtio-net | e1000 is 100× slower on a paravirtualized guest |

> [!important] 512 MiB cannot boot the Arch ISO
> The installer ramdisk needs ≥1024 MiB; the wiki notes the ISO fails to find
> `/dev/disk/by-label/ARCH_*` with the 128 MiB default. Install with 2048 MiB,
> then drop the running guest to 512 MiB. A cloud image has no installer, so 512
> MiB works from the first boot.

### 2. Host prerequisites

```bash
LC_ALL=C.UTF-8 lscpu | grep Virtualization
ls -la /dev/kvm
lsmod | grep kvm
```

Expected: `Virtualization: VT-x` (Intel) or `AMD-V` (AMD), `/dev/kvm` present,
and `kvm_intel` or `kvm_amd` loaded.

If `/dev/kvm` is missing, VT-x/AMD-V is disabled in the firmware — reboot into
BIOS and enable it. On Arch the KVM modules ship in the `linux` package; there
is nothing to build.

> [!warning] Check the mode on `/dev/kvm`
> The stock udev rule is `0660 root:kvm`. If you see `crw-rw-rw-`, someone
> chmod'd it and **every local user can open KVM**. Fix it and find out why:
> ```bash
> sudo chmod 660 /dev/kvm
> udevadm test /sys/class/misc/kvm
> ```

### 3. Packages

```bash
# Headless guests only
sudo pacman -S --needed qemu-base libvirt virt-install dnsmasq

# Optional: graphical console via virt-manager / virt-viewer
sudo pacman -S --needed qemu-desktop virt-manager virt-viewer

# Optional: TPM 2.0 guests (Windows 11)
sudo pacman -S --needed swtpm

# Optional: UEFI guests — read §7 before installing this
sudo pacman -S --needed edk2-ovmf

# Optional but recommended
sudo pacman -S --needed qemu-guest-agent passt cloud-init
```

`libvirt` pulls in `polkit`, `numactl`, `parted` and the rest. `dnsmasq` is
needed for the default NAT network's DHCP and DNS. `virtiofsd` and `qemu-img`
already come with `qemu-base`.

`passt` is only required for the passt networking mode in §5; it replaces the
bridge + dnsmasq + firewall machinery with a single unprivileged process.
`cloud-init` is only needed on the **host** if you build NoCloud images
yourself — the Arch cloud image already has it baked in.

### 4. Daemon and permissions

```bash
sudo systemctl enable --now libvirtd.service
systemctl status libvirtd.service
```

`libvirtd.service` also enables `virtlogd.socket` and `virtlockd.socket` — do not
enable those separately.

Do **not** also enable the modular `virtqemud.socket`; the monolithic and
modular daemons conflict.

Two independent permissions, both requiring a fresh login:

```bash
sudo usermod -aG kvm "$USER"       # /dev/kvm
sudo usermod -aG libvirt "$USER"    # libvirt RW socket, no password prompt
```

> [!warning] Group changes need a re-login
> Group membership is evaluated at login time. Nothing works until you log out
> and back in — not a re-login of the shell, a full session re-login.

You are already in `wheel`, so polkit would authenticate you with a password
prompt instead. The `libvirt` group skips the prompt.

Verify:

```bash
groups | tr ' ' '\n' | grep -E '^(kvm|libvirt)$'
virsh -c qemu:///system list --all
```

### 5. Networking

Three modes, in increasing cost.

#### 5a. passt — cheapest, no root, no bridge

libvirt 9.0.0 added a `passt` backend for user-mode interfaces; 11.1.0 added
the faster `vhostuser` variant. You get a full IPv4+IPv6 stack, a DHCP server,
and host→guest port forwarding, with **no bridge, no dnsmasq, no firewall
rules** and no privileges.

```bash
virt-install ... --network passt,portForward=127.0.0.1:2222:22
```

Equivalent XML:

```xml
<interface type='user'>
  <backend type='passt'/>
  <mac address='52:54:00:11:22:33'/>
  <portForward proto='tcp' address='127.0.0.1'>
    <range start='2222' to='22'/>
  </portForward>
</interface>
```

`to` is the guest port: the forwarded session lands on `start + (to - start)`.
Omitting `address` forwards from every host IP, so pin it to `127.0.0.1`
unless you mean to expose the port on the LAN.

#### 5b. default NAT — the usual choice

The `default` network (`virbr0`, `192.168.122.0/24`) is created and started
automatically. DHCP via dnsmasq, outbound via NAT.

```bash
virsh net-list --all
virsh net-dhcp-leases default
```

Downside: **inbound connections are blocked**. Use passt or a `route`/`open`
network if you need the host to reach the guest.

If you run nftables with `policy drop`, libvirt's rules are not enough on their
own:

```bash
# /etc/nftables.conf
table inet filter {
  chain input {
    type filter hook input priority filter
    policy drop
    iifname virbr0 udp dport {53, 67} accept comment "VM dhcp/dns to host"
  }
  chain forward {
    type filter hook forward priority filter
    policy drop
    iifname virbr0 accept
    oifname virbr0 accept
  }
}
```

```bash
sudo nft -f /etc/nftables.conf
```

#### 5c. bridged — only if the guest must be a LAN peer

```bash
nmcli con add type bridge con-name br0 ifname br0
nmcli con add type bridge-slave ifname enp3s0 master br0 con-name br0-port
nmcli con up br0
```

Then `--network bridge=br0`. Use `nmcli` rather than raw `ip link` so the
bridge survives reboots.

### 6. Boot source: a cloud image, not an installer

Arch ships two generic images: `basic` (a plain install) and `cloudimg` (the
same, with cloud-init baked in and login accounts locked). Take the cloud one.

```bash
mkdir -p ~/cloud-images && cd ~/cloud-images
curl -O https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2
curl -O https://geo.mirror.pkgbuild.com/images/latest/Arch-Linux-x86_64-cloudimg.qcow2.SHA256
sha256sum -c Arch-Linux-x86_64-cloudimg.qcow2.SHA256
```

Expected:

```text
Arch-Linux-x86_64-cloudimg.qcow2: OK
```

The download is ~550 MiB; the image advertises a **2 GiB virtual disk** and is
a qcow2 v3 file with 64 KiB clusters.

Keep the pristine copy outside the libvirt pool so it is never a live disk:

```bash
sudo install -d -m 0755 /var/lib/libvirt/images/base
sudo install -m 0644 -o libvirt-qemu -g libvirt-qemu \
  ~/cloud-images/Arch-Linux-x86_64-cloudimg.qcow2 \
  /var/lib/libvirt/images/base/archlinux-cloudimg.qcow2
```

The default login account in the Arch cloud image is **`arch`**. Debian,
Ubuntu, AlmaLinux and Rocky publish cloud images too, with cloud-init
preinstalled and their own default accounts (`debian`, `ubuntu`,
`ec2-user`, `rocky`); use those when the guest needs a wider package set.

### 7. Firmware: stay on BIOS unless Windows

```bash
# Firmware autoselection — libvirt picks what matches the guest
--boot uefi
```

**Default (no `--boot uefi`) is SeaBIOS.** That is the right choice for Linux
guests: smaller, boots faster, and sidesteps a live regression.

> [!danger] `edk2-ovmf` ≥ 202505-1 breaks GRUB Linux guests in UEFI mode
> After updating to `edk2-ovmf` 202505-1, many Linux distributions that use
> GRUB in UEFI mode become unbootable — known examples include Rocky Linux,
> Debian, RHEL and Fedora, and their live ISOs. **Still broken in 202508-1**;
> Arch currently ships 202608-1.
>
> Symptoms: the graphical SPICE console freezes, the serial console prints a
> page fault, and QEMU pins one core at 100%.
>
> Workarounds: stay on SeaBIOS (recommended for Linux guests); downgrade to
> `edk2-ovmf` 202411-1 and hold it; apply the Debian edk2 patch; or install
> `edk2-ovmf-fedora` (AUR) and point the loader path at it.
> Tracking: `archlinux/packaging/packages/edk2#9`

Windows 11 additionally requires **UEFI + TPM 2.0 + VirtIO drivers** — all
three. Add the TPM through virt-manager (Add Hardware → TPM → Emulator, TIS,
2.0); libvirt starts and supervises the `swtpm` process itself, so do not
launch `swtpm` by hand.

### 8. Create the VM

First, the disk. An **overlay** keeps the base image pristine and makes each
VM cost only its delta:

```bash
sudo qemu-img create -f qcow2 \
  -b /var/lib/libvirt/images/base/archlinux-cloudimg.qcow2 \
  -F qcow2 \
  /var/lib/libvirt/images/micro.qcow2
```

```bash
sudo qemu-img info /var/lib/libvirt/images/micro.qcow2
```

Expected:

```text
virtual size: 2 GiB (2147483648 bytes)
disk size: 192 KiB
backing file: /var/lib/libvirt/images/base/archlinux-cloudimg.qcow2
```

Now the guest itself:

```bash
virt-install \
  --connect qemu:///system \
  --name micro \
  --memory memory=1024,currentMemory=512 \
  --vcpus 1,maxvcpus 2 \
  --cpu host-model \
  --osinfo name=archlinux \
  --disk path=/var/lib/libvirt/images/micro.qcow2,format=qcow2,target.bus=virtio,driver.discard=unmap \
  --network network=default,model=virtio \
  --controller type=usb,model=none \
  --video none \
  --features pvspinlock=on \
  --rng /dev/urandom \
  --memballoon virtio \
  --cloud-init clouduser-ssh-key=$HOME/.ssh/id_ed25519.pub,disable=on \
  --import \
  --noautoconsole
```

#### Why each flag is there

| Flag | What it buys |
|---|---|
| `--memory memory=1024,currentMemory=512` | boot at 512 MiB, ceiling 1024 MiB for ballooning |
| `--vcpus 1,maxvcpus 2` | one vCPU now, hotpluggable to two |
| `--cpu host-model` | exposes the host CPU; needed for KVM acceleration to be worth anything |
| `--disk path=...,target.bus=virtio` | virtio-blk instead of emulated IDE |
| `driver.discard=unmap` | passes guest TRIM through to the qcow2 file |
| `--controller type=usb,model=none` | removes the USB controller entirely |
| `--video none` | instructs libvirt not to add a default video device (supported since libvirt 4.6.0) |
| `--features pvspinlock=on` | paravirtual spinlocks; less guest CPU burn while idle |
| `--rng /dev/urandom` | virtio-rng; **without it a headless guest can stall on entropy for minutes at boot** |
| `--memballoon virtio` | lets the host reclaim unused guest pages |
| `--cloud-init clouduser-ssh-key=...,disable=on` | injects your public key into the image's default cloud-init account (`arch` for the Arch cloud image), then detaches the NoCloud ISO and stops re-running |
| `--import` | no install phase — wrap the existing disk |
| `--noautoconsole` | do not block on a console we do not want |

> [!caution] `--memory` has a legacy trap
> A bare `--memory 512` maps to the XML `<currentMemory>` element, not
> `<memory>`. To be explicit, always use the sub-option form
> `--memory memory=1024,currentMemory=512`. Check the result with
> `--print-xml`.

#### Check before you commit

```bash
virt-install \
  --connect qemu:///system \
  --name micro \
  --memory memory=1024,currentMemory=512 \
  --vcpus 1,maxvcpus 2 \
  --osinfo name=archlinux \
  --disk path=/var/lib/libvirt/images/micro.qcow2,format=qcow2,target.bus=virtio \
  --network network=default,model=virtio \
  --controller type=usb,model=none \
  --video none \
  --rng /dev/urandom \
  --cloud-init clouduser-ssh-key=$HOME/.ssh/id_ed25519.pub,disable=on \
  --import \
  --dry-run --print-xml 2
```

`--dry-run` creates nothing; `--print-xml 2` prints the generated domain XML
without defining the guest. Read it — it is the cheapest way to catch a bad
flag combination before a disk is written.

#### Variations

| Goal | Change |
|---|---|
| Graphical console | `--graphics spice,listen=127.0.0.1 --video virtio` |
| Host port forward, no bridge | `--network passt,portForward=127.0.0.1:2222:22` |
| Start on host boot | add `--autostart` |
| Throwaway VM | add `--transient` (discarded on shutdown; disks survive) |
| Hard memory ceiling | `--memtune hard_limit=1048576,soft_limit=786432,swap_hard_limit=2097152` |
| Install Arch instead of cloud image | add `--cdrom /path/archlinux.iso --osinfo detect=on,require=on,name=archlinux` |

### 9. Guest-side setup

```bash
virsh start micro
```

Wait for cloud-init to finish, then:

```bash
virsh domifaddr micro --source agent
ssh arch@192.168.122.<n>
```

`arch` is the default account in the Arch cloud image; the public key you
passed to `--cloud-init clouduser-ssh-key=` is already in its `authorized_keys`.
Cloud images lock password logins, so if you need `sudo` inside the guest, set
a password for yourself first:

```bash
passwd arch
```

Inside the guest:

```bash
pacman -S qemu-guest-agent
systemctl enable --now qemu-guest-agent
```

The agent is not optional in practice. Without it `virsh shutdown` falls back to
ACPI and the guest can sit for a full minute waiting for a shutdown that never
lands. With it, `virsh shutdown` is immediate and `virsh domifaddr` can report
the guest IP.

For a serial console (needed if the guest has no network yet), the guest kernel
must be booted with `console=ttyS0`:

```bash
virsh console micro
```

### 10. Day-2 operations

```bash
# Lifecycle
virsh start micro
virsh shutdown micro          # graceful — needs the guest agent
virsh destroy micro           # hard power-off
virsh reboot micro

# Autostart on host boot
virsh autostart micro
sudo systemctl enable libvirt-guests.service   # suspend/resume on host suspend

# Snapshots (qcow2 only) — the workhorse of small-VM workflows
virsh snapshot-create-as micro clean --disk-only --atomic
virsh snapshot-list micro
virsh snapshot-revert micro clean
virsh snapshot-delete micro clean

# Overlay disks: base stays pristine, each VM writes only its delta
sudo qemu-img create -f qcow2 \
  -b /var/lib/libvirt/images/base/archlinux-cloudimg.qcow2 \
  -F qcow2 \
  /var/lib/libvirt/images/<name>.qcow2
```

`--disk-only` snapshots store only the disk, not the memory or device state —
that is what you want for a template, and it is cheap.

To point an existing overlay at a moved base image:

```bash
sudo qemu-img rebase -b /new/path/base.qcow2 /var/lib/libvirt/images/micro.qcow2
```

> [!warning] The backing path is absolute and embedded
> Moving a base image breaks every overlay that references it. Either keep the
> base at a fixed path forever, or `qemu-img rebase` each overlay afterwards.

### 11. Post-creation tuning

`virsh edit micro` is the escape hatch for anything the CLI does not expose:

```bash
virsh edit micro
```

```xml
<features>
  <hyperv>
    <relaxed state='on'/>
    <vapic state='on'/>
    <spinlocks state='on' retries='8191'/>
  </hyperv>
</features>
<devices>
  <memballoon model='virtio'/>
</devices>
```

libvirt assigns the PCI addresses; do not hand-write them.

Over-commit several small guests onto one host by giving each a ceiling well
above its start size and letting the balloon shrink them:

```bash
--memory memory=2048,currentMemory=512
```

Eight guests that each boot at 512 MiB but idle at 80 MiB fit in 2 GiB of
host RAM instead of 8.

---

## Gotchas

> [!warning] `cache=none` is incompatible with qcow2
> qcow2 cannot use `O_DIRECT`, so `--disk cache=none` fails on qcow2 volumes.
> Use `driver.io=threads` (the default) or `cache=writeback`.

> [!warning] `--cloud-init` without `disable=on` re-runs on every boot
> cloud-init will keep re-applying its config, which can reset the root
> password or the injected SSH keys out from under you.

> [!warning] Arch ISO + virtio disk needs the driver loaded
> If the installer cannot see the disk, drop to the live shell and run
> `modprobe virtio_blk`, or install with `target.bus=sata` and switch to virtio
> afterwards.

> [!caution] `virsh destroy` is a power cut
> It is the equivalent of pulling the plug. Filesystem damage is possible. Use
> `virsh shutdown` and wait.

> [!warning] A VM started by raw `qemu-system-x86_64` is invisible to libvirt
> It will not appear in `virsh list` and libvirt cannot manage, snapshot or
> shut it down. Never mix the two workflows on the same disk.

> [!warning] `libvirtd.service` and `virtqemud.socket` conflict
> Pick one mode. Do not enable both.

> [!tip] `--print-xml` is the best debugging tool here
> When a flag combination misbehaves, `--dry-run --print-xml 2` shows exactly
> what libvirt would have created, without touching storage.

---

## Verification

```bash
# 1. daemon
systemctl is-active libvirtd
# → active

# 2. KVM reachable and correctly permissioned
ls -la /dev/kvm
# → crw-rw---- 1 root kvm

# 3. pools and networks
virsh pool-list --all
# → default    active    yes
virsh net-list --all
# → default    active    yes

# 4. connection works
virsh -c qemu:///system list --all

# 5. the guest is accelerated, not emulated
virsh qemu-monitor-command micro --hmp 'info kvm'
# → kvm support: enabled
```

> [!important] `info kvm` is the check that matters
> "disabled" here means QEMU fell back to TCG software emulation. Everything
> else in this note assumes KVM. A GUI console that feels unbearably slow is
> almost always this.

```bash
# 6. the device budget actually applied
virsh dumpxml micro | grep -E '<video|<controller|<rng|<memballoon'
# → <controller model='none'>, <rng model='virtio'>, <memballoon model='virtio'>
#   and either no <video> element at all or one with model='none'

# 7. guest IP discovered via the agent
virsh domifaddr micro --source agent

# 8. clean shutdown reaches 'shut off' in seconds, not a minute
virsh shutdown micro && virsh list --all

# 9. disk footprint is the delta, not the virtual size
du -sh /var/lib/libvirt/images/micro.qcow2
# → a few hundred MiB at most, not 2 GiB

# 10. the base image is untouched
sudo qemu-img check /var/lib/libvirt/images/base/archlinux-cloudimg.qcow2
```

---

## Related

- [[libvirt-virt-manager]] — the general libvirt setup this note builds on: daemon,
  authentication, storage pools, bridged networking, UEFI and TPM details
- [[qemu-automated-testing]] — the direct-QEMU path with no libvirt; the right
  choice for CI pipelines where you want every flag visible
- [[arch-setup]] — host provisioning; libvirt belongs in the base install

---

## Sources

- [Libvirt — ArchWiki](https://wiki.archlinux.org/title/Libvirt) — daemon setup and
  modular vs monolithic daemons, polkit and the `libvirt` group, storage pools,
  forwarding modes, UEFI and TPM configuration, guest agent IP retrieval
- [QEMU — ArchWiki](https://wiki.archlinux.org/title/QEMU) — QEMU package variants
  and their split, KVM enablement, overlay storage images and `qemu-img rebase`,
  virtio device guidance, performance tuning checklist
- [QEMU/Troubleshooting — ArchWiki](https://wiki.archlinux.org/title/QEMU/Troubleshooting)
  — the `edk2-ovmf` GRUB regression in UEFI mode and its workarounds, the
  1024 MiB minimum for booting an Arch ISO, `/dev/kvm` permission errors
- [KVM — ArchWiki](https://wiki.archlinux.org/title/KVM) — hardware verification,
  nested virtualization, Secure Boot key enrolment
- [virt-install(1) — Arch manual pages](https://man.archlinux.org/man/virt-install.1.en)
  — authoritative option reference: `--memory` sub-options, `--disk`, `--network`
  including the passt backend, `--cloud-init`, `--rng`, `--memballoon`,
  `--features`, `--controller`, `--video`, `--dry-run`, `--print-xml`
- [libvirt: Domain XML format](https://libvirt.org/formatdomain.html) — `<video>`
  model `none`, `<memory>` vs `<currentMemory>` vs `<maxMemory>`, the passt
  backend and `<portForward>` ranges, memory ballooning, memory tuning
- [libvirt: Network XML format](https://libvirt.org/formatnetwork.html) — forward
  modes (`nat`, `route`, `open`, `bridge`, `isolated`), the default network
  definition, DHCP ranges and dnsmasq options
- [Arch Linux generic cloud images](https://geo.mirror.pkgbuild.com/images/latest/)
  — the `basic` and `cloudimg` qcow2 files, their `.SHA256` sums, and the fact
  that the cloud image is a 2 GiB virtual disk
- [OpenStack Virtual Machine Image Guide — Get images](https://docs.openstack.org/image-guide/obtain-images.html)
  — the default login account per distro cloud image (`arch` for Arch Linux,
  `debian`, `ubuntu`, `ec2-user`, `rocky`), which is what
  `--cloud-init clouduser-ssh-key=` targets

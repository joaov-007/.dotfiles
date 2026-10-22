---
title: "Kernel Hardening"
aliases:
  - Kernel Hardening
  - sysctl hardening
  - linux-hardened
  - kernel modules
  - kernel lockdown
  - module signature enforcement
description: >-
  Runtime hardening of the Arch kernel: choosing between linux, linux-lts, linux-zen and
  linux-hardened, the sysctl set that closes the cheap classes of exploit, blacklisting unused
  modules, and the boot-time lockdown plus module-signature enforcement that make an unsigned
  kernel module impossible to load rather than merely detectable.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - kernel
  - sysctl
  - kernel-modules
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  The kernel layer on a single Arch host: kernel choice, sysctl values, module policy, and the
  boot-time lockdown/signature parameters. Does not cover the command line itself or Secure
  Boot — that is [[Boot and Secure Boot]].
platform:
  - arch-linux
  - linux-kernel
keywords:
  - linux-hardened vs linux
  - /etc/sysctl.d/99-hardening.conf
  - sysctl --system
  - dmesg_restrict
  - kptr_restrict
  - yama.ptrace_scope
  - unprivileged_bpf_disabled
  - unprivileged_userns_clone
  - max_user_namespaces
  - randomize_va_space
  - mmap_rnd_bits
  - fs.protected_fifos
  - modules_disabled
  - modprobe blacklist
  - lockdown=confidentiality
  - module.sig_enforce=1
  - hardened_malloc
  - LKRG
related:
  - "[[Boot and Secure Boot]]"
  - "[[Access Control and Authentication]]"
  - "[[Security Principles for Arch Linux]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Kernel Hardening

> [!summary] One-paragraph answer
> Most kernel hardening on Arch is **runtime**: a `/etc/sysctl.d/99-hardening.conf` that hides
> kernel pointers, restricts `dmesg`, `ptrace` and unprivileged BPF, and a `/etc/modprobe.d/`
> blacklist for the dozen network protocols no desktop uses. The structural layer —
> `lockdown=` and `module.sig_enforce=1` on the command line — belongs with
> [[Boot and Secure Boot]]. `linux-hardened` sounds stronger but lags mainline; a stock `linux`
> kernel plus these settings is usually the better trade (see [[Security Principles for Arch Linux]]).

## Context

Open this when you want to raise the cost of a kernel exploit or reduce the code reachable from
userspace, and you have already decided your threat model. It assumes you are on a desktop or a
single-purpose server; the aggressive values are marked, because several of them break Flatpak,
podman, hibernation or out-of-tree drivers.

## Details

### 1. Choose a kernel

| Package | Character | When it is right |
|---|---|---|
| `linux` | mainline, current | the default; pair with sysctls below |
| `linux-lts` | older, slower cadence | you value stability over the newest mitigations |
| `linux-zen` | desktop-tuned | low-latency workloads |
| `linux-hardened` | extra hardening patches | only if you can tolerate lag |

```bash
# a second kernel as a fallback is a security control in itself
sudo pacman -S linux-lts linux-lts-headers
```

> [!note] `linux-hardened` is not automatically the right answer
> It applies extra self-protection but can trail mainline by several point releases, which is
> itself a risk. Many prefer stock `linux` with the runtime settings below. Check CPU
> mitigations rather than relying on a name:

```bash
grep -r . /sys/devices/system/cpu/vulnerabilities/    # expect Mitigation: or Not affected
```

### 2. sysctl hardening

Create `/etc/sysctl.d/99-hardening.conf`:

```ini
# === Kernel info leaks ===
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
kernel.yama.ptrace_scope = 2
kernel.unprivileged_bpf_disabled = 1
kernel.kexec_load_disabled = 1
kernel.sysrq = 0
kernel.randomize_va_space = 2
kernel.core_uses_pid = 1

# === Link and FIFO attacks ===
fs.protected_hardlinks = 1
fs.protected_symlinks = 1
fs.protected_fifos = 2
fs.protected_regular = 2
fs.suid_dumpable = 2

# === IPv4 / IPv6 (network stack) ===
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_rfc1337 = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.all.use_tempaddr = 2

# === ASLR strength (test suspend/resume if you raise these) ===
vm.mmap_rnd_bits = 32
vm.mmap_rnd_compat_bits = 16
```

Apply and verify:

```bash
sudo sysctl --system
sudo sysctl kernel.kptr_restrict kernel.yama.ptrace_scope
```

> [!warning] Leave these OFF a daily-use desktop
> ```ini
> kernel.unprivileged_userns_clone = 0
> user.max_user_namespaces = 0     # kills Flatpak, bubblewrap, podman, rootless containers
> kernel.modules_disabled = 1      # irreversible until reboot (see §3)
> ```
> These are correct on a server with a fixed, known module set and wrong on the machine you work
> on. The reasoning is in [[Security Principles for Arch Linux]].

### 3. Blacklist the modules you do not use

A large fraction of kernel attack surface is protocols no desktop speaks. Blacklist them:

```ini
# /etc/modprobe.d/hardening-blacklist.conf
blacklist firewire-core
blacklist firewire-ohci
blacklist thunderbolt
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
blacklist n_hdlc
blacklist ax25
blacklist netrom
blacklist x25
blacklist rose
blacklist decnet
blacklist econet
blacklist ipx
blacklist appletalk
blacklist can
blacklist atm
```

> [!danger] `kernel.modules_disabled = 1` is a one-way door
> Setting it prevents **any** further module load until reboot. If hardware or a service needs a
> module afterwards, you cannot load it — you reboot, or you are stuck. Only set it after
> confirming `lsmod` contains everything you need, and never on a machine whose hardware you
> have not fully exercised.

### 4. Lockdown and module signatures

The command line carries the two parameters that make unsigned kernel code structurally
unloadable:

```
lockdown=confidentiality module.sig_enforce=1
```

- `module.sig_enforce=1` — refuse modules that are not signed with a key the kernel trusts.
- `lockdown=integrity` — block kernel writes and `/dev/mem` style access; keeps most features.
- `lockdown=confidentiality` — stricter; **breaks hibernation and out-of-tree modules** (ZFS,
  NVIDIA, VirtualBox).

Where to put them (UKI / `/etc/kernel/cmdline`) and how they interact with Secure Boot is covered
in [[Boot and Secure Boot]].

### 5. Optional, and honest about their limits

```bash
# hardened_malloc — a memory allocator that makes heap exploits harder (AUR)
#   pairs with: vm.max_map_count = 1048576
# LKRG — Linux Kernel Runtime Guard, detects some kernel integrity violations (AUR)
```

> [!caution] These are supplements, not substitutes
> Both are bypassable by a determined, kernel-level attacker, and both add breakage risk
> (`hardened_malloc` needs a `LD_PRELOAD`/`/etc/ld.so.preload`-free integration and a higher
> `vm.max_map_count`). Treat them as defence in depth on top of signatures and lockdown, never
> as the control that replaces them.

## Gotchas

> [!warning] Applying a CIS/server sysctl set to a desktop
> The most common breakage: `max_user_namespaces = 0` (no Flatpak/podman), the full IPv4 set
> combined with an output-drop firewall (see [[Firewall Configuration]]), and `tcp_timestamps = 0`
> on NFS/VPN links.

> [!caution] Sysctl values that only apply at load time
> `kernel.modules_disabled` and `kernel.kexec_load_disabled` cannot be relaxed after being set in
> the running kernel — a reboot is the only reset. Test them on a VM or snapshot first.

> [!warning] `mmap_rnd_bits = 32` and suspend/resume
> Raising ASLR entropy is good, but on some firmware/hibernation paths it interacts badly. If
> suspend or resume breaks, that is the first value to lower.

## Verification

```bash
# the key values took effect
sysctl kernel.dmesg_restrict kernel.kptr_restrict kernel.yama.ptrace_scope \
       kernel.unprivileged_bpf_disabled fs.protected_regular

# no unexplained kernel taint
cat /proc/sys/kernel/tainted        # 0 = clean

# command-line hardening is present
grep -oE 'lockdown=[a-z]+|module\.sig_enforce=1' /proc/cmdline

# no unneeded protocol modules loaded
lsmod | grep -E 'dccp|sctp|rds|tipc|ax25|can'   # expect nothing
```

## Related

- [[Boot and Secure Boot]] — where `lockdown=` and `module.sig_enforce=1` are set
- [[Access Control and Authentication]] — the user-space half of restricting what code can do
- [[Security Principles for Arch Linux]] — why the aggressive values are options, not defaults

## Sources

- [Sysctl — ArchWiki](https://wiki.archlinux.org/title/Sysctl) — drop-in layout under
  `/etc/sysctl.d/`, `sysctl --system`
- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — the recommended sysctl set
  and the "know your threat model" framing
- [Kernel — ArchWiki](https://wiki.archlinux.org/title/Kernel) — `linux-hardened` status and the
  mainline-lag caveat
- [Kernel parameters — ArchWiki](https://wiki.archlinux.org/title/Kernel_parameters) —
  `lockdown=`, `module.sig_enforce=1`, and `/etc/kernel/cmdline`
- [Linux kernel sysctl documentation](https://docs.kernel.org/admin-guide/sysctl/kernel.html) —
  authoritative meaning of each `kernel.*` value
- [Madaidan — Linux Hardening Guide](https://madaidans-insecurities.github.io/guides/linux-hardening.html)
  — the maximalist sysctl set, and where `hardened_malloc`/LKRG fit

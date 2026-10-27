---
title: "Arch Linux Security Hardening"
aliases:
  - Arch Linux Security Hardening
  - arch hardening guide
  - hardening MOC
  - security hardening guide
description: >-
  Map of content for the Arch Linux hardening notes: what each domain note covers, the order to
  read or apply them, and the consolidated checklist. The old single-file guide lived here; it
  is now split into focused notes that each own one layer of the stack.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - moc
  - self-audit
type: moc
status: draft
created: 2026-09-28
updated: 2026-10-14
last_reviewed: 2026-10-14
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Hub for the arch-linux/hardening notes. Holds the reading order, the note map and the
  consolidated checklist; the procedures themselves live in the linked notes.
platform:
  - arch-linux
keywords:
  - hardening checklist
  - defence in depth
  - threat model
  - reading order
  - arch hardening map
related:
  - "[[Security Principles for Arch Linux]]"
  - "[[Arch Lifecycle — Install, Maintain, Recover]]"
  - "[[Disk Encryption]]"
  - "[[Boot and Secure Boot]]"
  - "[[Kernel Hardening]]"
  - "[[Access Control and Authentication]]"
  - "[[Firewall Configuration]]"
  - "[[SSH Hardening]]"
  - "[[Network and Browser Privacy]]"
  - "[[systemd and Application Sandboxing]]"
  - "[[Resource Limits and Fine-Tuning]]"
  - "[[Filesystem and Physical Security]]"
  - "[[Monitoring, Integrity and Auditing]]"
  - "[[Rootkit and Backdoor Detection]]"
  - "[[arch-hardening-runbook]]"
  - "[[arch-setup]]"
cssclasses:
  - index
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Arch Linux Security Hardening

> [!summary] One-paragraph answer
> Hardening is **defence in depth for a stated threat model**, not a checklist you finish. This
> note is the map: it names the layers, the order to apply them in, and the questions each note
> answers. Start with [[Security Principles for Arch Linux]] to fix a threat model, apply
> structural controls (encryption, verified boot, default-deny firewall) before detective ones
> (scanners), and keep the machine **secure and useful**.

## Context

The former single-file guide has been split into focused notes, one per layer, grouped by
domain folder. Read this page to choose where to start; each linked note is self-contained with
its own Gotchas, Verification and Sources. Machine-specific, already-executed work stays in the
runbook ([[arch-hardening-runbook]]).

## The map

| Layer | Note | Answers |
|---|---|---|
| Frame | [[Security Principles for Arch Linux]] | *Which* attacks am I defending against? |
| Lifecycle | [[Arch Lifecycle — Install, Maintain, Recover]] | What do I do before install, and how do I keep and restore it? |
| At rest | [[Disk Encryption]] | Is data unreadable if the disk is stolen? |
| Boot | [[Boot and Secure Boot]] | Can an attacker boot around my kernel? |
| Kernel | [[Kernel Hardening]] | How much of the kernel is reachable and abusable? |
| Identity | [[Access Control and Authentication]] | Who may log in, and what may each program do? |
| Network edge | [[Firewall Configuration]] | What may connect in? |
| Remote access | [[SSH Hardening]] | Is my remote door key-only and minimal? |
| Network privacy | [[Network and Browser Privacy]] | What does the machine leak out? |
| Services | [[systemd and Application Sandboxing]] | What can a running service or app reach? |
| Resources | [[Resource Limits and Fine-Tuning]] | How much may each user or service consume? |
| Local | [[Filesystem and Physical Security]] | What stops code executing here, or a hand on the keyboard? |
| Detection | [[Monitoring, Integrity and Auditing]] | How do I know if something changed? |
| Detection | [[Rootkit and Backdoor Detection]] | Is something hiding in runtime state? |

## Suggested reading order

1. [[Security Principles for Arch Linux]] — fix the threat model first; everything else is optional
   until you have.
2. [[Arch Lifecycle — Install, Maintain, Recover]] — prevention starts before the first boot.
3. [[Disk Encryption]] → [[Boot and Secure Boot]] → [[Kernel Hardening]] — the structural stack,
   strongest first.
4. [[Access Control and Authentication]] → [[systemd and Application Sandboxing]] → [[Resource Limits and Fine-Tuning]] — confine users
   and processes, then bound what they consume.
5. [[Firewall Configuration]] → [[SSH Hardening]] → [[Network and Browser Privacy]] — the network
   surface.
6. [[Filesystem and Physical Security]] — the local surface.
7. [[Monitoring, Integrity and Auditing]] → [[Rootkit and Backdoor Detection]] — detection last,
   because it only reports *after* the others fail.

## Consolidated checklist

Tick what your threat model justifies — not what a scanner scores. Every line links to the note
that owns it.

**Pre-install** — [[Arch Lifecycle — Install, Maintain, Recover]]
- [ ] UEFI administrator password set; legacy/CSM boot disabled
- [ ] Arch ISO signature verified
- [ ] Package set minimal

**At rest and boot** — [[Disk Encryption]], [[Boot and Secure Boot]]
- [ ] LUKS2 full-disk encryption, LVM on LUKS
- [ ] Encrypted swap (or zram) — never plain swap
- [ ] Unified Kernel Image built
- [ ] Secure Boot enrolled (`sbctl`) and bootloader editor disabled
- [ ] `lockdown=` and `module.sig_enforce=1` on the command line
- [ ] Boot directory permissions locked (`chmod 700 /boot`)

**Kernel** — [[Kernel Hardening]]
- [ ] `/etc/sysctl.d/99-hardening.conf` applied (`dmesg_restrict`, `kptr_restrict`, `ptrace_scope`,
      `unprivileged_bpf_disabled`, `fs.protected_*`)
- [ ] Unused protocol modules blacklisted
- [ ] `modules_disabled=1` considered (server only)

**Access** — [[Access Control and Authentication]]
- [ ] AppArmor enabled and enforcing
- [ ] `pam_faillock` configured; `nullok` removed
- [ ] Password quality enforced; root locked
- [ ] `sudo` hardened (`use_pty`, logging); umask `077`

**Network** — [[Firewall Configuration]], [[SSH Hardening]], [[Network and Browser Privacy]]
- [ ] Firewall default-drop on input and forward
- [ ] SSH key-only, no root, forwarding off (or `sshd` disabled)
- [ ] Encrypted DNS configured
- [ ] MAC address randomization
- [ ] Chatty services (Avahi/CUPS/Bluetooth) disabled if unused

**Services and filesystem** — [[systemd and Application Sandboxing]], [[Resource Limits and Fine-Tuning]], [[Filesystem and Physical Security]]
- [ ] Services confined (`Protect*`, `Private*`, `SystemCallFilter`)
- [ ] Per-user slice budget set (`CPUWeight`, `MemoryHigh`/`MemoryMax`, `TasksMax`, `IOWeight`)
- [ ] `limits.conf` (`nproc`, `nofile`, `core`, `nice`) reviewed against the desktop needs
- [ ] `systemd-oomd` thresholds confirmed with `oomctl`; swap/zram present
- [ ] Unneeded services masked
- [ ] `noexec`, `nosuid`, `nodev` on `/tmp` and `/var/tmp`; sticky bit set
- [ ] USBGuard (or USB storage disabled) if physical access matters
- [ ] Screen lock enabled

**Detection and recovery** — [[Monitoring, Integrity and Auditing]], [[Rootkit and Backdoor Detection]], [[Arch Lifecycle — Install, Maintain, Recover]]
- [ ] AIDE baseline built **and copied offline**
- [ ] `auditd` watches on identity/sudoers/sshd
- [ ] journald persistent, ideally shipped off-host
- [ ] Recurring `lynis` score and `arch-audit`
- [ ] Btrfs snapshots + a tested 3-2-1 backup + offline recovery key

## Gotchas

> [!warning] A checklist is not a threat model
> Every "yes" above is a decision with a cost. The desktop-breaking controls (output-drop
> firewall, `noexec` on `/home`, `modules_disabled=1`, `lockdown=confidentiality`) are correct on
> a server and wrong on a workstation. The reasons are in [[Security Principles for Arch Linux]].

> [!caution] Applying top-down beats scraping a score
> A fleet of scanners on a machine that boots an unverified kernel is misallocated effort. Fix
> the structural layers first; they are what actually bounds the risk.

## Verification

There is no single command. The closest is the recurring audit loop:

```bash
sudo lynis audit system --quiet 2>&1 | grep -i 'hardening index'   # track drift
arch-audit                                                         # advisories vs installed
sudo aide --check                                                  # files unchanged
cat /proc/sys/kernel/tainted                                       # 0
sudo systemctl is-enabled sshd.service 2>/dev/null || echo 'sshd disabled'
```

## Related

- [[Security Principles for Arch Linux]] — read this first
- [[arch-hardening-runbook]] — the machine-specific, executed companion (host `bacon`)
- [[arch-setup]] — the install this hardening assumes
- [[Monitoring, Integrity and Auditing]] · [[Rootkit and Backdoor Detection]] — the detection end

## Sources

- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — the distro's own baseline,
  and the "your threat model decides" framing that structures this whole set
- [ArchWiki](https://wiki.archlinux.org/) — per-topic pages, each cited in the note that uses it
- [Madaidan — Linux Hardening Guide](https://madaidans-insecurities.github.io/guides/linux-hardening.html)
  and [PrivSec — Desktop Linux Hardening](https://privsec.dev/posts/linux/desktop-linux-hardening/)
  — the maximalist and pragmatic ends of the spectrum, used as menus
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) —
  "never trust, always verify"; least privilege; assume the network is hostile
- [Red Hat — Build a foundation for zero trust in Linux environments](https://www.redhat.com/en/resources/build-a-foundation-for-zero-trust-overview)
  — the OS-level capability map this set uses as a cross-check

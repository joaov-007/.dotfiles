---
title: "Security Principles for Arch Linux"
aliases:
  - Security Principles for Arch Linux
  - security principles
  - hardening principles
  - threat model
  - defence in depth
description: >-
  The mental model behind every other hardening note: start from a threat model, then apply
  least privilege, defence in depth and attack-surface reduction — and accept the trade-off
  between a secure system and a useful one.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - threat-modeling
  - self-audit
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Conceptual foundation for the arch-linux/hardening notes. No commands; it explains how to
  choose which hardening steps to apply.
platform:
  - arch-linux
keywords:
  - threat model
  - attack surface
  - least privilege
  - defence in depth
  - secure and useful
  - risk tolerance
related:
  - "[[Arch Linux Security Hardening]]"
  - "[[Arch Lifecycle — Install, Maintain, Recover]]"
  - "[[Kernel Hardening]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Security Principles for Arch Linux

> [!summary] One-paragraph answer
> Hardening is not a checklist you complete once; it is the practice of reducing the ways a
> system can be attacked **for a specific threat model**. Work in this order: decide who you are
> defending against, apply the smallest set of changes that meaningfully raises the cost of an
> attack, and prefer *structural* controls (encryption, signed boot, allow-lists) over
> *detective* ones (scanners). Every other note in this folder is an instance of this model.

## Context

Read this before the concrete notes. The rest of the folder assumes you have decided *which*
attacks you care about, because the same change can be essential for one person and pure
friction for another. A server that serves the internet wants a default-drop firewall and no
graphical stack. A single-user Niri desktop wants neither a strict output firewall nor `noexec`
on `/home`, because both break daily work for a threat you may never face.

## Details

### 1. Start from a threat model

Write down, in one line each, what you are protecting and from whom. The categories that matter
on a Linux desktop:

| Threat | Example | First-line control |
|---|---|---|
| Physical access | Stolen laptop, "evil maid" | Full-disk encryption, Secure Boot, UEFI password |
| Network | Remote exploit, port scan | Firewall, no exposed services, patching |
| Malware | Browser exploit, bad download | Sandboxing, MAC, on-demand scanning |
| Insider / multi-user | Another local account | User separation, sudo rules, ptrace restrictions |
| Supply chain | Compromised package or AUR PKGBUILD | Signed packages, minimal AUR, reproducible builds |
| Boot chain | Tampered kernel or initramfs | UKI + Secure Boot + signed modules |

If a control does not map to a row you actually care about, it is optional — and optional
controls that break your workflow tend to get disabled, which is worse than never enabling them.

### 2. The five principles

| Principle | In practice |
|---|---|
| **Least privilege** | Services run as their own user; `sudo` not `su`; capabilities, not root |
| **Defence in depth** | Independent layers, so one failure is not total compromise |
| **Minimise attack surface** | Fewer packages, fewer listeners, fewer kernel modules, fewer AUR builds |
| **Assume failure** | Have a recovery path (snapshots, offline backups, recovery key) |
| **Be a little paranoid** | Unusual state is worth explaining, not ignoring |

### 3. Rank controls by strength, not by effort

The strongest controls make an attack **impossible** rather than merely **detectable**:

1. **Structural prevention** — encryption at rest, Secure Boot + signed kernel modules, a
   default-drop firewall, a minimal AUR surface.
2. **Isolation** — MAC (AppArmor), systemd sandboxing, Flatpak/bubblewrap.
3. **Detection** — AIDE, auditd, rootkit scanners, integrity checks. Valuable, but they only
   tell you after the fact.

Spend effort top-down. A fleet of scanners on a system that boots unsigned kernels is
misallocated effort.

### 4. The "secure and useful" trade-off

> You can never make a system 100% secure unless you unplug it from all networks, turn it off,
> lock it in a safe, smother it in concrete and never use it. The goal is a system that is
> **secure *and* useful**.

Concrete examples of controls deliberately **not** recommended for a daily-use desktop, each
with the reason:

| Control | Why it is often skipped on a desktop |
|---|---|
| Output-chain `policy drop` | Breaks mDNS, Syncthing, browsers, local model servers |
| `noexec` on `/home` | Breaks Wine, Steam, PyCharm, scripts, .NET |
| `kernel.modules_disabled=1` | Irreversible until reboot; one missing module = no boot |
| `user.max_user_namespaces=0` | Kills Flatpak, bubblewrap, podman, rootless containers |
| `lockdown=confidentiality` | Breaks hibernation and out-of-tree modules (NVIDIA, ZFS, VirtualBox) |
| Resident `clamd` | ~1 GB RAM for a threat model on-demand scanning already covers |

These are *correct* on a hardened server and *wrong* on the machine you work on. Know which one
you are configuring.

### 5. How to read the risk tags in this folder

Each procedure note marks its steps as one of:

- **safe** — no effect on daily use; apply freely.
- **trade-off** — a real cost (RAM, a broken feature, babysitting); decide per threat model.
- **aggressive** — irreversible or boot-affecting; test on a snapshot or a VM first.

### 6. Zero trust — the same principles, formalised

"Never trust, always verify" is the name this model acquired in enterprise security (NIST
SP 800-207). It is worth knowing because it supplies the vocabulary and a checklist, and because
it extends the model to actors a desktop guide usually ignores.

The three principles:

1. **Never trust an actor implicitly — always verify.** No host, user, network or service inside
   the perimeter is trusted by default; every connection is authenticated *and* authorised
   before it is allowed.
2. **Least privilege.** Grant the smallest set of rights that lets an actor do its job — a
   service user, a capability, a scoped `sudo` rule, a confined AppArmor profile.
3. **Assume the network is compromised.** Encryption and authentication are mandatory on the
   wire, not an optimisation.

Mapped onto the layers this folder covers:

| Zero-trust idea | Where it is applied here |
|---|---|
| Verify every actor (human and non-human) | [[Access Control and Authentication]] — PAM, FIDO2, hardened services |
| Least privilege | [[systemd and Application Sandboxing]] — `Protect*`, caps; scoped `sudo` |
| Assume the network hostile | [[Firewall Configuration]], [[Network and Browser Privacy]], [[SSH Hardening]] |
| Hardware root of trust / measured boot | [[Boot and Secure Boot]], [[Disk Encryption]] — TPM2, Secure Boot |
| Encryption in use / in transit / at rest | [[Disk Encryption]], TLS, [[Network and Browser Privacy]] |
| Monitor and log every transaction, off-host | [[Monitoring, Integrity and Auditing]] — auditd, remote journald |
| Verified supply chain / SBOM | [[Arch Lifecycle — Install, Maintain, Recover]], [[Rootkit and Backdoor Detection]] — signed packages, minimal AUR |

> [!note] Where the enterprise framing does not transfer
> Centralised identity (SSO, LDAP, certificate issuance) and fleet automation are out of scope
> on a single-user desktop; a hardware-backed SSH/FIDO2 key and `systemd-cryptenroll` are the
> local equivalents. Treat the enterprise table above as a cross-check for *coverage*, not as a
> build order — the build order is §3 (structural first).

## Gotchas

> [!warning] Applying a server checklist to a desktop
> The most common failure is copying a CIS/server hardening guide verbatim onto a workstation.
> The commands succeed; the desktop then misbehaves in ways that are hard to trace back. Read
> the *risk tag* in each note before running its commands.

> [!caution] Security theatre
> A control that does not map to a threat in your model is theatre. A changed SSH port is not a
> security control (the ArchWiki says so outright); it only reduces log noise.

## Verification

You have a workable threat model when you can answer, without hedging: *which* of the six
threat rows you care about, and for each, which single control you would apply first. If a
proposed change does not serve one of those rows, it can wait.

## Related

- [[Arch Linux Security Hardening]] — the map of content for this folder
- [[Kernel Hardening]] — the highest-leverage structural layer
- [[Arch Lifecycle — Install, Maintain, Recover]] — prevention starts before install

## Sources

- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — the distro's own baseline
  and its repeated "your threat model decides" framing
- [Madaidan — Linux Hardening Guide](https://madaidans-insecurities.github.io/guides/linux-hardening.html)
  — the maximalist end of the spectrum; useful as a menu, not a mandate
- [PrivSec — Desktop Linux Hardening](https://privsec.dev/posts/linux/desktop-linux-hardening/)
  — pragmatic desktop-oriented counterpart, including the "secureblue" module list
- [Kicksecure — security-misc](https://github.com/Kicksecure/security-misc) — concrete values for
  the aggressive end, useful to see what "maximal" actually costs
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) — the
  formal statement of "never trust, always verify" and the least-privilege model in §6
- [Red Hat — Build a foundation for zero trust in Linux environments](https://www.redhat.com/en/resources/build-a-foundation-for-zero-trust-overview)
  — an OS-level capability map (MAC, allow-listing, measured boot, logging, compliance scanning)
  used here as a coverage cross-check

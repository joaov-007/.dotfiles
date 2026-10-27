---
title: "systemd and Application Sandboxing"
aliases:
  - systemd and Application Sandboxing
  - systemd service hardening
  - service sandboxing
  - firejail
  - bubblewrap
description: >-
  Confining what runs: the systemd `Protect*`/`SystemCallFilter` directives that shrink a
  service's view of the system, drop-in overrides for services you cannot edit, masking what
  you do not run — and the userspace sandboxes (Firejail, Flatpak/bubblewrap, systemd-nspawn)
  that apply the same idea to desktop applications.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - systemd
  - sandboxing
  - services
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-14
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Service confinement via systemd units and drop-ins, and application sandboxing with Firejail,
  Flatpak/bubblewrap and systemd-nspawn. Does not cover MAC profiles — see
  [[Access Control and Authentication]].
platform:
  - arch-linux
  - systemd
keywords:
  - NoNewPrivileges
  - ProtectSystem=strict
  - ProtectHome
  - PrivateTmp
  - PrivateDevices
  - ProtectKernelModules
  - ProtectProc=invisible
  - ProcSubset=pid
  - RestrictSUIDSGID
  - MemoryDenyWriteExecute
  - SystemCallFilter=@system-service
  - SystemCallArchitectures=native
  - systemd drop-in
  - systemctl mask
  - firejail firecfg
  - bubblewrap bwrap
  - systemd-nspawn
  - systemd-analyze security
related:
  - "[[Access Control and Authentication]]"
  - "[[Resource Limits and Fine-Tuning]]"
  - "[[Firewall Configuration]]"
  - "[[flatpak-portal-permissions]]"
  - "[[Security Principles for Arch Linux]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# systemd and Application Sandboxing

> [!summary] One-paragraph answer
> A service that runs as root with a full view of the filesystem is a single bug away from
> system compromise. systemd lets you take that view away with `Protect*`, `Private*`,
> `Restrict*` and `SystemCallFilter` directives — most of them a one-line addition to a drop-in.
> The same idea applied to desktop apps is sandboxing: Firejail for arbitrary binaries,
> Flatpak/bubblewrap for packaged apps, `systemd-nspawn` for full containers. Non-human actors
> deserve the same least privilege as users.

## Context

Open this when you are running a network-facing service, or when you want to bound the damage a
desktop application can do if it is exploited. Start with services that already run as root and
have no business doing so.

## Details

### 1. Inspect first — see how exposed a unit is

```bash
systemd-analyze security sshd.service
# prints a numbered, colour-coded exposure score with per-directive suggestions
```

The score is not a verdict; it is a to-do list. Each line names the directive that would raise it.

### 2. The hardening template

For anything you write yourself:

```ini
# /etc/systemd/system/hardened@.service
[Unit]
Description=Hardened service %i

[Service]
Type=simple
ExecStart=/usr/bin/%i
Restart=on-failure

NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectClock=true
ProtectProc=invisible
ProcSubset=pid
RestrictSUIDSGID=true
LockPersonality=true
RestrictRealtime=true
RestrictNamespaces=true
MemoryDenyWriteExecute=true
SystemCallFilter=@system-service
SystemCallErrorNumber=EPERM
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
```

> [!danger] `ProtectSystem=strict` makes the whole filesystem read-only
> Legacy services that write to `/var` or `/etc` will fail until you add a
> `ReadWritePaths=/var/lib/example` line. Add the exception, do not drop the protection.

### 3. Drop-ins for services you do not own

Never edit a package's unit — a `pacman -Syu` overwrites it. Use a drop-in:

```bash
sudo systemctl edit sshd.service      # creates /etc/systemd/system/sshd.service.d/override.conf
```

```ini
# /etc/systemd/system/sshd.service.d/hardening.conf
[Service]
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
RestrictSUIDSGID=true
ReadWritePaths=/run/sshd
```

```bash
sudo systemd-analyze verify sshd.service
sudo systemctl daemon-reload && sudo systemctl restart sshd
systemd-analyze security sshd.service   # the score should drop
```

### 4. Mask what you do not run

`mask` symlinks a unit to `/dev/null` so nothing — not even a dependency — can start it:

```bash
sudo systemctl mask cups.service avahi-daemon.service bluetooth.service ModemManager.service
```

> [!note] `disable` vs `mask`
> `disable` stops automatic start but allows manual/`--now` and dependency starts. `mask` makes
> the unit unstartable. Use `mask` for services you have decided must never run.

### 5. Application sandboxes

| Tool | Sandbox for | Cost |
|---|---|---|
| **Firejail** | any binary, via a profile | easy to break apps; needs profiles |
| **Flatpak/bubblewrap** | Flathub apps | portal permissions to review |
| **systemd-nspawn** | full OS containers | heavier; for services/testing |

```bash
# Firejail — install, then wire it into desktop launchers
sudo pacman -S firejail firetools
sudo firecfg                     # symlinks app launchers to firejail versions
firejail firefox                 # ad-hoc: run one app sandboxed
firejail --net=none /usr/bin/untrusted-app

# bubblewrap — the primitive Flatpak is built on
sudo pacman -S bubblewrap
bwrap --ro-bind / / --dev /dev --proc /proc --tmpfs /tmp --unshare-all /bin/sh

# nspawn — a contained OS
sudo pacman -S arch-install-scripts
sudo systemd-nspawn -D /var/lib/machines/box --boot
```

> [!tip] Flatpak is the lowest-friction desktop sandbox
> Packaged apps are confined by default; the tunable part is the portal permissions. Review them
> with Flatseal or `flatpak override`, and see [[flatpak-portal-permissions]] and [[flatpak-apps]]
> for the vault's catalogue.

## Gotchas

> [!warning] `SystemCallFilter` can be too aggressive
> A filter that blocks a syscall a service needs makes it crash on an unusual code path. Test
> with the service exercised fully, and use `SystemCallLog=` to log rather than block while
> tuning.

> [!caution] `PrivateTmp` changes where `/tmp` points
> Two services with `PrivateTmp` do not share `/tmp`. If a service hands a file to another
> process through `/tmp`, they will not see each other's files.

> [!danger] `firecfg` rewrites launchers
> `sudo firecfg` symlinks system launchers to Firejail. A missing or wrong profile can stop an
> app from starting. `firecfg --clean` reverses it.

## Verification

```bash
systemd-analyze security sshd.service            # exposure score, lower is better
systemctl cat sshd.service | grep -E 'Protect|Private|NoNewPriv'  # drop-in applied
systemctl is-enabled cups.service avahi-daemon.service            # masked
firejail --version && flatpak --version 2>/dev/null
```

## Related

- [[Access Control and Authentication]] — MAC is the other way to confine a process
- [[Firewall Configuration]] — bounding what a service can reach on the network
- [[flatpak-portal-permissions]] — the desktop-facing sandbox permission model
- [[Security Principles for Arch Linux]] — least privilege for every actor, human or not

## Sources

- [systemd — ArchWiki](https://wiki.archlinux.org/title/Systemd) — drop-ins, `mask`,
  `daemon-reload`
- [systemd.exec(5)](https://man.archlinux.org/man/systemd.exec.5) — authoritative list of the
  `Protect*`, `Private*`, `Restrict*` and `SystemCallFilter` directives
- [systemd-analyze(1)](https://man.archlinux.org/man/systemd-analyze.1) — `security`, `verify`
- [Firejail — ArchWiki](https://wiki.archlinux.org/title/Firejail) — `firecfg`, profiles
- [Bubblewrap — ArchWiki](https://wiki.archlinux.org/title/Bubblewrap) — `bwrap` usage
- [systemd-nspawn — ArchWiki](https://wiki.archlinux.org/title/Systemd-nspawn) — containers
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) —
  non-human actors authenticated and least-privileged

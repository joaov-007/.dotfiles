---
title: "NixOS Security Hardening — bacon"
aliases:
  - nixos security hardening
  - bacon nixos security
  - nixos hardening
description: >-
  Verified security baseline and hardening plan for the NixOS host `bacon` in
  `~/.dotfiles/nixos`: what the repo already defines, what is wired into the host, gaps found,
  tooling availability in nixpkgs, and safe next steps. Grounded in local config inspection and
  official NixOS/ArchWiki sources.
tags:
  - nixos
  - security
  - hardening
  - clamav
  - aide
  - auditd
  - apparmor
  - lynis
  - malware-scanning
  - rootkit
type: runbook
status: needs-action
confidence: high
created: 2026-11-27
updated: 2026-11-27
last_reviewed: 2026-11-27
review_after: 2027-05-27
language: en
audience: maintainer
scope: NixOS host bacon security baseline and declarative hardening
platform:
  - NixOS
  - systemd
host: bacon
os: NixOS (flake, nixos#bacon)
repo: /home/joaov/.dotfiles
keywords:
  - NixOS hardening
  - nixpkgs rkhunter unavailable
  - chkrootkit removed nixpkgs
  - lynis
  - unhide
  - clamav desktop notification
  - auditd
  - AppArmor
  - AIDE
  - fangfrisch
findings:
  - id: security-module-not-wired
    severity: high
    status: resolved-in-repo
    summary: "security module now imported in nixosConfigurations.bacon; pending user switch to apply on running system"
  - id: rkhunter-missing-nixpkgs
    severity: medium
    status: open
    summary: "rkhunter is not packaged in nixpkgs (eval error: Did you mean urlhunter?); chkrootkit removed from nixpkgs. Documented; lynis+unhide added as available alternatives."
  - id: clamav-notification-basic
    severity: low
    status: resolved-in-repo
    summary: "ClamAV desktop notification enhanced in config (critical urgency, icon, recent findings, DBUS/XDG fallback, logger). Pending switch."
sources:
  - title: "Security - NixOS Wiki"
    url: "https://wiki.nixos.org/wiki/Security"
    kind: official-doc
    supports: "NixOS security model, multi-user store isolation, hardening pointers"
  - title: "NixOS Hardening - NixOS Wiki"
    url: "https://wiki.nixos.org/wiki/NixOS_Hardening"
    kind: official-doc
    supports: "Kernel/systemd hardening options and trade-offs"
  - title: "nixos/modules/profiles/hardened.nix (nixos-25.11)"
    url: "https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/profiles/hardened.nix"
    kind: source
    supports: "Hardened profile enables options known to affect stability/features/performance"
  - title: "Security - ArchWiki"
    url: "https://wiki.archlinux.org/title/Security"
    kind: reference
    supports: "Defense in depth, least privilege, passwords, audit, AppArmor, sandboxing"
  - title: "Hardening NixOS - nix-book"
    url: "https://saylesss88.github.io/nix/hardening_NixOS.html"
    kind: guide
    supports: "Practical NixOS hardening ideas including Lynis/ClamAV/AIDE; cross-check before applying"
  - title: "Hardening_NixOS - NixOS Blog (tsawyer87)"
    url: "https://tsawyer87.github.io/posts/hardening_nixos/"
    kind: blog
    supports: "Community hardening patterns; verify against current NixOS options"
related:
  - "[[arch-linux-hardening]]"
  - "[[arch-hardening-runbook]]"
  - "[[Rootkit and Backdoor Detection]]"
  - "[[Monitoring, Integrity and Auditing]]"
  - "[[system-diagnostics-and-self-healing]]"
  - "[[Home]]"
cssclasses:
  - wide-table
---

# NixOS Security Hardening — bacon

> [!summary] One-paragraph answer
> The `~/.dotfiles/nixos` repo already defines solid security building blocks (auditd, firewall logging, AppArmor, ClamAV with fangfrisch and scanner, AIDE with daily timer), but the aggregated `security` module is **not imported** into `nixosConfigurations.bacon`. The immediate NixOS-safe path is: wire the security module into bacon, improve ClamAV desktop virus notifications, add available scanners (`lynis`, `unhide`), and document that `rkhunter` is not in nixpkgs and `chkrootkit` was removed upstream — without pretending they are installed.

## Context

User concern (2026-11-27): "não estou confiando no meu nixos se ele é seguro". Requested: research (blogs, ArchWiki, NixOS blogs, official docs), install/add security programs including rkhunter ("rk") and ClamAV, look for other security programs, and update wiki carefully. Follow-up: "Setup clama desktop notification for virus 🦠🦟 add this cools features".

> [!warning] Scope and honesty
> This note distinguishes **verified repo state**, **nixpkgs availability checks**, and **planned/config changes**. It does not claim a rebuild/switch was performed. Applying NixOS changes requires the user to run a privileged rebuild.

## Verified current state (repo inspection)

| Area | Evidence | Status |
|---|---|---|
| Security base module | `nixos/modules/system/security/default.nix` defines `flake.modules.nixos.securityBase` with `security.auditd.enable`, `security.audit.enable`, firewall logReversePathDrops/logRefusedConnections, `/etc/issue`, `security.apparmor.enable` | Defined |
| ClamAV module | `nixos/modules/system/security/clamav.nix` enables daemon/updater/scanner/fangfrisch, scans `/home/joaov/Downloads`, and notifies on `clamdscan.onFailure` with critical desktop notification (recent FOUND/INFECTED lines, icon, DBUS/XDG fallback, logger) | Defined/enhanced in repo; pending switch |
| AIDE module | `nixos/modules/system/security/aide.nix` installs `pkgs.aide`, writes `/etc/aide.conf`, creates `/var/log/aide`, runs daily `aide-check` timer at 04:30 with randomized delay, notifies on failure | Defined |
| Security aggregate | `nixos/modules/attrs/security/default.nix` imports `securityBase`, `aide`, `clamav` as `flake.modules.nixos.security` | Defined |
| Bacon host wiring | `nixos/modules/attrs/hosts/bacon/defaults.nix` now includes `security` in host modules | Wired in repo; pending switch |
| Security tools module | `nixos/modules/system/security/tools.nix` adds `lynis`, `unhide`; documents rkhunter/chkrootkit unavailable in nixpkgs | Defined and wired via `attrs/security` |
| Doas | `nixos/modules/system/security/doas.nix` enables doas, passwordless for `joaov`, disables sudo | Wired in bacon defaults |

## Implementation status (2026-11-27)

Implemented in repo by Nix Ninja, verified by CTO inspection:

- `nixos/modules/attrs/hosts/bacon/defaults.nix`: added `security` to host modules.
- `nixos/modules/attrs/security/default.nix`: includes `securityTools`.
- `nixos/modules/system/security/tools.nix`: new module adding `lynis` and `unhide`; comment documents `rkhunter`/`chkrootkit` nixpkgs unavailability.
- `nixos/modules/system/security/clamav.nix`: enhanced desktop virus notification (`notify-send --urgency=critical --icon=security-high --app-name=ClamAV`, recent `FOUND/INFECTED/ERROR/Eicar` lines from `journalctl -u clamdscan -n 80`, DBUS/XDG_RUNTIME fallback, `logger` fallback, `onFailure` kept).

Validation reported by Nix Ninja and build artifact verified locally:

```bash
nixos-rebuild build --flake /home/joaov/.dotfiles/nixos#bacon
# result -> /nix/store/x8plmiaafi21mnlsfl6vymgcqy9k49dw-nixos-system-bacon-26.11.20261121.2786a2a
```

> [!warning] Not applied on the running system
> No `switch` was performed. The user must apply it manually: `run0 nixos-rebuild switch --flake /home/joaov/.dotfiles/nixos#bacon`.

## NixOS-relevant security tooling availability (nixpkgs eval, 2026-11-27)

Commands run (read-only): `nix eval --json nixpkgs#<pkg>.meta.name`.

| Tool | nixpkgs | Notes |
|---|---|---|
| `clamav` | ✅ `clamav-1.5.5` | Already modeled in repo module |
| `aide` | ✅ `aide-0.19.5` | Already modeled in repo module |
| `lynis` | ✅ `lynis-3.1.7` | Good audit/hardening scanner; add declaratively |
| `unhide` | ✅ `unhide-20240510` | Forensic proc/net/sys hiding checks; useful complement |
| `rkhunter` | ❌ not found | Eval: `Did you mean urlhunter?` — cannot install via nixpkgs attr as-is |
| `chkrootkit` | ❌ removed | nixpkgs throws: "chkrootkit has been removed as it is unmaintained and archived upstream and didn't even work on NixOS" |

> [!important] rkhunter request
> The user asked for "rk (the rootkit search)". In NixOS, prefer available/maintained tools: `lynis`, `unhide`, AIDE, auditd, and careful boot/kernel hardening. If rkhunter is still required, it needs a custom Nix package/overlay with maintenance cost and should be reviewed carefully; do not install imperatively outside Nix.

## Recommended NixOS hardening direction (desktop-safe)

### 1) Wire existing security module into bacon
Add `security` to `flake.nixosConfigurations.bacon.modules` in `nixos/modules/attrs/hosts/bacon/defaults.nix`. Validate build before switch.

### 2) Improve ClamAV desktop notification (follow-up)
Current: critical notify on `clamdscan.onFailure` with generic message. Improve by:
- including recent infected/found lines from `journalctl -u clamdscan` in notification body (bounded size);
- keeping `--urgency=critical` and clear title/icon;
- ensuring service has usable desktop session env when running as user (test on actual session; avoid noisy notifications on clean scans).

### 3) Add available security tools
- `lynis` for periodic security auditing.
- `unhide` for hidden process/port checks.
- Consider `tiger`/`vulnix`/`ossec` equivalents only after evaluating maintenance and NixOS fit; do not add blindly.

### 4) Avoid risky blanket hardening on desktop
NixOS wiki hardened profile warns about stability/feature/performance impact. Do **not** blindly enable `profiles/hardened.nix` on bacon desktop. Evaluate individually:
- `kernel.unprivileged_userns_clone`/userns restrictions can break Flatpak, browsers, containers.
- strict AppArmor kill modes can break workflows; keep rollout incremental.
- `ProtectHome/ProtectSystem` service hardening should be per-service, tested.

## Verification (after config changes, before/after rebuild)

```bash
# Repo-side validation (no sudo)
cd /home/joaov/.dotfiles
nixos-rebuild build --flake ./nixos#bacon

# After user applies switch (requires privilege)
run0 nixos-rebuild switch --flake /home/joaov/.dotfiles/nixos#bacon

# Post-switch checks
systemctl status auditd clamav-daemon clamav-freshclam clamav-fangfrisch.timer aide-check.timer --no-pager
journalctl -u clamdscan -n 50 --no-pager
sudo aa-status || doas aa-status
lynis --version
unhide --version 2>&1 | head -5
```

## Wiki/docs follow-up

- Keep this note factual and update status after Nix Ninja implements/validates.
- Cross-link from `Home.md` / security section only after confirming paths and avoiding duplication with Arch-specific runbook.
- Update `meta/hardening-todos.md` with a NixOS/bacon phase if we track execution there.

## Sources

- NixOS Wiki — Security: https://wiki.nixos.org/wiki/Security
- NixOS Wiki — NixOS Hardening: https://wiki.nixos.org/wiki/NixOS_Hardening
- nixpkgs hardened profile: https://github.com/NixOS/nixpkgs/blob/nixos-25.11/nixos/modules/profiles/hardened.nix
- ArchWiki — Security: https://wiki.archlinux.org/title/Security
- nix-book — Hardening NixOS: https://saylesss88.github.io/nix/hardening_NixOS.html
- tsawyer87 — Hardening NixOS: https://tsawyer87.github.io/posts/hardening_nixos/
- Xe Iaso — Paranoid NixOS Setup: https://xeiaso.net/blog/paranoid-nixos-2021-07-18/
- chobble — Hardening NixOS: https://blog.chobble.com/blog/24-11-28-hardening-nixos/

---
title: "Arch Hardening — Todo Tracker"
aliases:
  - Hardening Todos
  - Hardening tracker
description: >-
  Working tracker for the Arch hardening project: research, audit, AIDE, ClamAV and
  rootkit-detection phases, with per-item status and the next action for the user.
tags:
  - meta
  - hardening
  - runbook
  - arch-linux
  - audit
type: runbook
status: needs-action
confidence: high
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: maintainer
scope: Session tracker for the arch-linux/hardening work
related:
  - "[[arch-hardening-runbook]]"
  - "[[arch-linux-hardening]]"
cssclasses:
  - reference
keywords:
  - hardening
  - lynis
  - aide
  - clamav
  - audit
platform:
  - Arch Linux
  - systemd
---

# Arch Hardening — Todo Tracker
Started: 2026-10-10

## Phase 1 — Research
- [x] 1.1 Gather ArchWiki recommendations (Security, sudo, firewall, kernel hardening, SSH)
- [x] 1.2 Gather blog/extra recommendations (sysctl, file permissions, services)
- [x] 1.3 Verify fangfrisch exact name + availability (pacman/AUR) → `python-fangfrisch` AUR

## Phase 2 — System audit (read-only by agent; user runs sudo manually)
- [x] 2.1 Snapshot current state: firewall, sysctl, services, users, permissions (no sudo)
- [x] 2.2 Provide user manual commands: install lynis, run audit (in wiki §2)
- [ ] 2.3 Record/interpret lynis findings from user's output — AWAITING USER

## Phase 3b — AIDE (system integrity monitoring)
- [x] 3b.1 Verify aide in repos → AUR-only `aide 0.19.4-2`, PKGBUILD reviewed (PGP-verified source)
- [x] 3b.2 Provide install + init + first baseline + timer commands (in wiki §5)
- [x] 3b.3 Verify check workflow documented (aide --check / --update after pacman -Syu)

## Phase 3 — ClamAV + fangfrisch
- [x] 3.1 Provide pacman command for clamav + freshclam setup (in wiki §3)
- [x] 3.2 Find fangfrisch package + PKGBUILD review → python-fangfrisch 1.9.2-2, clean
- [x] 3.3 Configure freshclam + fangfrisch, first signature update, verify clamscan (in wiki §3–4)
- [x] 3.4 On-demand scan setup (no resident daemon — keep daily use fast) + optional timer §7

## Phase 4 — Apply safe hardening steps
- [x] 4.1 Select fixes safe for daily use from lynis + ArchWiki (wiki §6, each with risk tag)
- [x] 4.2 Give user manual commands with rollback notes (wiki §6 + Rollback table)

## Phase 4b — Rootkit & backdoor detection (documentation only)
- [x] 4b.1 Verify rkhunter/chkrootkit/unhide availability → rkhunter+unhide in extra, chkrootkit AUR
- [x] 4b.2 Research rootkit techniques (LKM, eBPF, /proc hiding, network, systemd, ld.so.preload)
- [x] 4b.3 Deep detection playbook: §6.4 layers A–G with verified bacon output
- [x] 4b.4 June 2026 AUR supply-chain attack IOC sweep (§6.2) — all clean on bacon
- [x] 4b.5 Update wiki §6 (threat model, scanners, manual hunt, false-pos table, IR, limitations)
- [x] 4b.6 Register 5 new tags in Vault Conventions §5

## Phase 5 — Wiki page
- [x] 5.1 Write wiki page in vault following Vault Conventions schema
- [x] 5.2 Validate frontmatter parses (root AGENTS.md validator is for flat *.md only)
- [x] 5.3 Cross-reference related pages + bump updated (Home, Vault Conventions tags, arch-linux-hardening)

## Deliverable
- NEW: arch-linux/hardening/arch-hardening-runbook.md (type=runbook, status=needs-action, confidence=high)
  - §1 install tools · §2 lynis · §3 ClamAV · §4 fangfrisch · §5 AIDE
  - §6 rootkit & backdoor detection (threat model, AUR supply-chain IOCs, rkhunter/chkrootkit/unhide,
    7-layer manual hunt A–G, false-pos table, incident response, honest limitations)
  - §7 low-risk cleanups · §8 scheduled scanning · Gotchas · Verification · Rollback · Sources
- New tags registered in meta/vault-conventions.md §5: hardening, clamav, aide, lynis, hids,
  file-integrity, malware-scanning, rootkit, backdoor, forensics, supply-chain, eBPF
- Home.md updated (note table + Security & hardening topic line)
- arch-linux-hardening.md related += arch-hardening-runbook, updated bumped to 2026-10-10
- Page now 1312 lines; frontmatter validated (16 tags, 12 findings, 15 actions, 10 sources)

## Notes / decisions log
- No sudo by agent; user runs privileged commands manually (password-required sudo)
- lynis/clamav/fangfrisch/aide NOT installed yet — copy-paste commands in wiki §1
- AUR PKGBUILDs for python-fangfrisch + aide cloned and reviewed, both clean
- aide is AUR-only on Arch (left official repos); alternative is auditd watches (auditd already on)
- avahi-daemon is the one unnecessary world-facing listener (0.0.0.0:5353) — disable recommended
- sysctls already strong: dmesg_restrict=1 kptr_restrict=2 ptrace_scope=2 bpf_disabled=1 syncookies=1 ASLR=2
- ufw active, sshd inactive, AppArmor in LSM chain, auditd on — good baseline
- Write to /tmp/opencode blocked by policy → todos live here (gitignored-style dotfile)

## Next action for user
Run wiki §1 installs, then §2 lynis baseline, and paste the hardening index + warnings back here
so findings can be recorded and the note status moved from needs-action.

## Phase 6 — Split the generic guide into focused notes (2026-10-10)
- [x] 6.1 Split `arch-linux-hardening.md` (was 1622 lines) into 12 domain notes + hub MOC
- [x] 6.2 Organise under `arch-linux/hardening/<domain>/` (foundations, disk, boot, kernel,
      access, network, services, detection)
- [x] 6.3 Conform every note to meta/vault-conventions schema (title/aliases/type/status/dates/
      sources/related)
- [x] 6.4 Extract generic rootkit playbook into `detection/rootkit-and-backdoor-detection.md`;
      runbook §6 reduced to bacon-specific verified results + link
- [x] 6.5 Fix runbook anchor links (`#20`, `#18`, `#5.2`, `#1`) → split notes
- [x] 6.6 Fold Red Hat / NIST SP 800-207 zero-trust framing into security-principles (§6) and
      cross-reference access-control + monitoring
- [x] 6.7 Register 22 new tags in Vault Conventions §5; bump Home + Vault Conventions updated
- [x] 6.8 Validate: all hardening wikilinks resolve; H1 == title; frontmatter parses

### New note inventory (all type=reference except hub=type=moc, all status=draft)
- arch-linux/hardening/arch-linux-hardening.md            (hub, moc, §21 checklist)
- foundations/security-principles.md                       (+ §6 zero trust)
- foundations/lifecycle-install-maintain-recover.md
- disk/disk-encryption.md
- disk/filesystem-and-physical.md
- boot/boot-and-secure-boot.md
- kernel/kernel-hardening.md
- access/access-control-and-authentication.md
- network/firewall.md
- network/ssh-hardening.md
- network/network-privacy.md
- services/systemd-and-sandboxing.md
- detection/monitoring-integrity-auditing.md
- detection/rootkit-and-backdoor-detection.md

### Resolved
- Folder depth: user approved 3 levels for `arch-linux/hardening/<domain>/`; Vault Conventions
  §6 amended to "up to three levels" (2026-10-10).

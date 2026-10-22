---
title: "Monitoring, Integrity and Auditing"
aliases:
  - Monitoring, Integrity and Auditing
  - integrity monitoring
  - auditd
  - AIDE
  - logging
description: >-
  Turning "did anything change?" into a routine: an AIDE baseline hashed and copied offline,
  auditd watches on the files that matter, persistent journald with logs shipped off the host,
  optional IMA/EVM measurement, and a repeatable hardening score (lynis) plus package-advisory
  scans. Detection, honestly labelled as detection.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - auditd
  - logging
  - monitoring
  - aide
  - hids
  - file-integrity
  - lynis
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  File-integrity monitoring, kernel auditing, logging and compliance/advisory scanning on a
  single Arch host. Rootkit/backdoor hunting is separate — see
  [[Rootkit and Backdoor Detection]].
platform:
  - arch-linux
  - systemd
keywords:
  - aide --init
  - aide --check
  - aide --update
  - offline AIDE database
  - auditd
  - auditctl -w
  - augenrules --load
  - /etc/audit/rules.d
  - journald Storage=persistent
  - SystemMaxUse
  - MaxRetentionSec
  - Remote logging
  - ima_policy
  - lynis audit system
  - openscap oscap
  - arch-audit
related:
  - "[[Rootkit and Backdoor Detection]]"
  - "[[Access Control and Authentication]]"
  - "[[Arch Lifecycle — Install, Maintain, Recover]]"
  - "[[Security Principles for Arch Linux]]"
  - "[[system-diagnostics-and-self-healing]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Monitoring, Integrity and Auditing

> [!summary] One-paragraph answer
> Prevention can fail silently; these controls make failure **visible**. AIDE hashes a set of
> system files (and the database is copied **off the host**, or a root attacker just rewrites
> it). auditd records who touched the sensitive files in real time. journald is made persistent
> and, ideally, shipped off the machine. lynis gives a repeatable hardening score and `arch-audit`
> maps advisories to installed packages. All of this is detection — it tells you *after* — so it
> complements, never replaces, the structural controls.

## Context

Open this after the prevention notes, when you want to know whether the system still looks the
way you left it. It is also the place a compliance scanner like OpenSCAP fits, though on Arch
lynis and `arch-audit` are the maintained paths.

## Details

### 1. AIDE — a file-integrity baseline

Third-party AIDE is the maintained integrity monitor on Arch (it left the official repos; the
AUR package is standard, or use `auditd` file watches below if you avoid AUR).

```bash
# tune /etc/aide.conf first: watch system paths, not volatile user data
#   keep stock rules; ensure these are in the watch set:
#   /etc  /boot  /usr/bin  /usr/sbin  /usr/lib/systemd/system
#   do NOT watch /home (noise), /var/log (rotates)

sudo aide --init
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz

sudo aide --check            # exit 0 = unchanged; non-zero = read the report

# after an intentional change (pacman -Syu, a config edit):
sudo aide --update && sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

> [!danger] Copy the baseline offline — the step everyone skips
> The AIDE database lives on the root filesystem. An attacker with root rewrites it to hide their
> changes. Copy `aide.db.gz` to read-only/offline media (a USB stick, a repository you push
> elsewhere) right after `--init`, and periodically compare against **that** copy.

### 2. auditd — the real-time record

```bash
sudo pacman -S audit
sudo systemctl enable --now auditd.service
```

```ini
# /etc/audit/rules.d/10-hardening.rules
-w /etc/passwd            -p wa -k identity
-w /etc/shadow            -p wa -k identity
-w /etc/sudoers           -p wa -k sudoers_changes
-w /etc/ssh/sshd_config   -p wa -k sshd_config
-w /usr/bin/sudo          -p x  -k sudo_exec
-a always,exit -F arch=b64 -S execve -C uid!=euid -k priv_escalation
```

```bash
sudo augenrules --load
sudo auditctl -l
# query the log by key later:
sudo ausearch -k identity -ts recent
```

> [!note] AIDE and auditd answer different questions
> | | AIDE | auditd |
> |---|---|---|
> | Detects | files that **changed** since baseline | file **access/changes** in real time |
> | Timing | periodic snapshot | continuous event log |
> | Question | "did `/usr/bin/sudo` get replaced?" | "who touched `/etc/shadow`, and when?" |
> Run both: AIDE's diff plus auditd's event log is a full picture.

### 3. Persistent logging — and get it off the host

```ini
# /etc/systemd/journald.conf
[Journal]
Storage=persistent
SystemMaxUse=500M
MaxRetentionSec=1month
Compress=yes
```

```bash
sudo mkdir -p /var/log/journal
sudo systemctl restart systemd-journald
```

> [!important] Local logs are tamperable by root
> A root attacker deletes their own tracks in `/var/log`. The durable fix is **remote logging**:
> forward journald over `systemd-journal-upload` (or rsyslog) to a second host you control, so
> the record survives the compromise of the machine that produced it. The Red Hat zero-trust
> checklist calls this "off-system log storage" for exactly this reason.

### 4. IMA/EVM — measurement (optional, kernel-level)

The Integrity Measurement Architecture appraises files against a known-good list at open time.
It needs kernel parameters and an enrollment step, and is more involved than AIDE:

```
ima_policy=tcb ima_appraise=fix evm=fix
```

Use it when you need runtime appraisal, not just a periodic diff; otherwise AIDE is enough.

### 5. Compliance and advisory scanning

```bash
# repeatable hardening score
sudo pacman -S lynis && sudo lynis audit system
sudo lynis audit system --quiet          # suggestions only

# map Arch security advisories to installed packages
sudo pacman -S arch-audit && arch-audit

# OpenSCAP, where a profile exists
sudo pacman -S openscap
sudo oscap xccdf eval --profile xccdf_org.ssgproject.content_profile_standard \
  --results scan-results.xml /usr/share/xml/scap/ssg/content/ssg-arch-ds.xml
```

> [!warning] A scanner's suggestions are a menu, not a mandate
> lynis does not know your use case and will suggest desktop-breaking things (output-drop
> firewall, `modules_disabled=1`, disabling USB storage). Cross-check each against the note that
> owns it before applying.

## Gotchas

> [!warning] AIDE screams after every `pacman -Syu`
> A full upgrade changes hundreds of files. Run `aide --update` after each upgrade, or read the
> diff and confirm the changes are only pacman's. Do not learn to ignore AIDE output — that is how
> a real change hides in the noise.

> [!caution] Do not run `aide --init` as the wrong user
> The AIDE database must be **root-owned**; the similar fangfrisch database must **not** be.
> Running the right tool as the wrong user creates files the consumer cannot read.

> [!danger] Chasing the lynis score
> Optimising for "100" pushes you into the exact controls that break daily use. Track the score
> for drift, not as a target.

## Verification

```bash
ls -l /var/lib/aide/aide.db.gz          # baseline exists, and a copy is off-host
sudo aide --check                        # exit 0 immediately after an --update
sudo auditctl -l | head                  # rules loaded
journalctl --disk-usage                  # persistent journal is populated
sudo lynis audit system --quiet 2>&1 | grep -i 'hardening index'
arch-audit                               # advisories against installed packages
```

## Related

- [[Rootkit and Backdoor Detection]] — the runtime-state lens AIDE and signature scanners miss
- [[Access Control and Authentication]] — auditd watches the files this note protects
- [[Arch Lifecycle — Install, Maintain, Recover]] — update hygiene that keeps the baseline honest
- [[Security Principles for Arch Linux]] — where detection sits below prevention

## Sources

- [AIDE — ArchWiki](https://wiki.archlinux.org/title/AIDE) — install, `--init`/`--check`/`--update`,
  the offline-database warning, AUR-only status
- [auditd — ArchWiki](https://wiki.archlinux.org/title/Audit) — rule files, `augenrules`, `ausearch`
- [systemd-journald — ArchWiki](https://wiki.archlinux.org/title/Systemd-journal) — persistence and
  remote logging
- [Lynis documentation](https://cisofy.com/documentation/lynis/) — audit usage and hardening index
- [OpenSCAP — ArchWiki](https://wiki.archlinux.org/title/OpenSCAP) — `oscap` profiles
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) —
  transaction monitoring and logging; off-system log storage

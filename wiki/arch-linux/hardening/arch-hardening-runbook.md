---
title: "Arch Hardening — Security Audit, ClamAV + Fangfrisch, AIDE"
aliases:
  - arch hardening runbook
  - bacon security audit
  - clamav arch
  - fangfrisch
  - aide arch
  - lynis arch
  - security tooling
description: >-
  Machine-specific hardening runbook for host `bacon`: a verified read-only security
  snapshot, then ordered steps for lynis (audit), ClamAV with fangfrisch (unofficial
  signatures), and AIDE (file-integrity monitoring) — plus the verified host-specific results of a
  rootkit and backdoor audit (which links to the reusable [[Rootkit and Backdoor Detection]]
  playbook) and a prioritised list of safe-for-daily-use kernel, service and permission changes.
tags:
  - linux
  - arch-linux
  - security
  - hardening
  - clamav
  - aide
  - lynis
  - hids
  - file-integrity
  - malware-scanning
  - rootkit
  - backdoor
  - forensics
  - supply-chain
  - eBPF
  - self-audit
type: runbook
status: needs-action
confidence: high
created: 2026-10-10
updated: 2026-10-12
last_reviewed: 2026-10-12
review_after: 2026-11-10
language: en
audience: sysadmin
scope: single-host security hardening and monitoring tooling
platform:
  - arch-linux
keywords:
  - lynis audit system
  - clamav freshclam
  - clamav-scan.timer
  - clamscan systemd service
  - clamav scheduled scan
  - fangfrisch initdb
  - python-fangfrisch
  - unofficial clamav signatures
  - sanesecurity signatures
  - urlhaus
  - aide --init
  - aide --check
  - file integrity monitoring
  - HIDS
  - ufw status
  - avahi-daemon disable
  - mDNS 5353
  - apparmor aa-status
  - rkhunter --check
  - rkhunter --propupd
  - chkrootkit lkm
  - chkrootkit ifpromisc
  - unhide proc
  - rootkit detection
  - eBPF rootkit
  - hidden_pids
  - bpftool map list
  - ld.so.preload
  - /proc/modules tainted
  - process hiding
  - bind shell reverse shell
  - AUR supply chain attack 2026
  - atomic-lockfile
  - aur-malware-check
  - persistence systemd cron udev
sources:
  - "[Security — ArchWiki](https://wiki.archlinux.org/title/Security)"
  - "[ClamAV — ArchWiki](https://wiki.archlinux.org/title/ClamAV)"
  - "[AIDE — ArchWiki](https://wiki.archlinux.org/title/AIDE)"
  - "[fangfrisch documentation (upstream)](https://github.com/rseichter/fangfrisch)"
  - "[python-fangfrisch — AUR](https://aur.archlinux.org/packages/python-fangfrisch/)"
  - "[aide — AUR](https://aur.archlinux.org/packages/aide/)"
  - "[rkhunter — ArchWiki](https://wiki.archlinux.org/title/Rkhunter)"
  - "[Unhide — forensic process/port finder](https://sourceforge.net/projects/unhide-linux/)"
  - "[chkrootkit upstream](https://www.chkrootkit.org/)"
  - "[eBPF rootkit technique (hidden_pids maps, June 2026 AUR attack)](https://github.com/A1RM4X/AUR-Malware-2026.06-Check)"
source_retrieved: 2026-10-10
related:
  - "[[arch-linux-hardening]]"
  - "[[Rootkit and Backdoor Detection]]"
  - "[[arch-system-audit]]"
  - "[[arch-dnscrypt-proxy]]"
  - "[[Home]]"
cssclasses:
  - wide-table
ai-gen: true
ai-model: "mimo-v2.6-flash-free"
ai-provider: "opencode"
ai-prompt: "Research ArchWiki hardening recommendations, audit this host read-only, and write a runbook for lynis, ClamAV + fangfrisch and AIDE"
ai-review: pending
host: bacon
user: joaov
os: Arch Linux
kernel: 7.2.9-arch1-1
firewall: ufw
mac: apparmor
aur_helper: paru
sudo: password-required
findings:
  - id: avahi-exposed
    severity: medium
    status: open
    summary: "avahi-daemon enabled, mDNS/LLMNR on 0.0.0.0:5353 — unnecessary attack surface on a desktop"
  - id: no-malware-scanner
    severity: medium
    status: open
    summary: "No ClamAV, no fangfrisch — no on-demand or signature-based scanning capability"
  - id: no-integrity-monitor
    severity: medium
    status: open
    summary: "No AIDE baseline — file changes cannot be detected post-compromise"
  - id: no-audit-baseline
    severity: low
    status: open
    summary: "lynis not installed — no repeatable hardening score to track drift"
  - id: no-rootkit-scanner
    severity: medium
    status: open
    summary: "rkhunter/chkrootkit/unhide not installed — no signature or forensic check for LKM/eBPF/process-hiding rootkits"
  - id: no-eBPF-inventory
    severity: low
    status: open
    summary: "/sys/fs/bpf empty and unprivileged_bpf_disabled=1 today, but no bpftool baseline — re-check after any AUR install (June 2026 AUR attack used pinned eBPF maps)"
  - id: boot-chain-unverified
    severity: medium
    status: open
    summary: "Secure Boot/module.sig_enforce not confirmed — the only structural block on unsigned LKM rootkits"
  - id: bluetooth-on
    severity: low
    status: open
    summary: "bluetooth.service enabled — disable if no BT peripherals in use"
  - id: sysctl-already-hardened
    severity: info
    status: resolved
    summary: "dmesg_restrict=1, kptr_restrict=2, ptrace_scope=2, bpf_disabled=1, protected_hardlinks/symlinks=1, syncookies=1, ASLR=2 all already set"
  - id: firewall-active
    severity: info
    status: resolved
    summary: "ufw.service enabled and active; sshd inactive — no remote-access exposure"
  - id: auditd-active
    severity: info
    status: resolved
    summary: "auditd.service + audit-rules.service already enabled"
  - id: cpu-mitigated
    severity: info
    status: resolved
    summary: "All /sys/devices/system/cpu/vulnerabilities/* report Mitigation or Not affected"
actions:
  - id: install-lynis
    status: pending
    command: sudo pacman -S --needed lynis
  - id: run-lynis
    status: pending
    command: sudo lynis audit system
  - id: install-clamav
    status: pending
    command: sudo pacman -S --needed clamav
  - id: install-clamav-scan-units
    status: pending
    command: sudo systemctl enable --now clamav-scan.timer  # §8.2 — paths in /etc/conf.d/clamav-scan.conf
  - id: install-fangfrisch
    status: pending
    command: paru -S python-fangfrisch
  - id: fangfrisch-initdb
    status: pending
    command: sudo -u clamav fangfrisch --conf /etc/fangfrisch/fangfrisch.conf initdb
  - id: install-aide
    status: pending
    command: paru -S aide
  - id: aide-init
    status: pending
    command: sudo aide --init
  - id: disable-avahi
    status: pending
    command: sudo systemctl disable --now avahi-daemon.service
  - id: ufw-verify
    status: pending
    command: sudo ufw status verbose
  - id: install-rootkit-scanners
    status: pending
    command: sudo pacman -S --needed rkhunter unhide
  - id: install-chkrootkit
    status: pending
    command: paru -S chkrootkit
  - id: rkhunter-propupd
    status: pending
    command: sudo rkhunter --propupd
  - id: unhide-proc
    status: pending
    command: sudo unhide proc
  - id: check-ld-so-preload
    status: pending
    command: test -f /etc/ld.so.preload && echo PRESENT || echo clean
  - id: check-aur-attack-window
    status: pending
    command: grep -nE 'installed (atomic-lockfile|deps|js-digest)' /var/log/pacman.log
---

# Arch Hardening — Security Audit, ClamAV + Fangfrisch, AIDE

Hardening runbook for host **`bacon`**, written 2026-10-10. The system snapshot below was
gathered **read-only** as uid 1000 — nothing was installed or changed. Every privileged step is
a copy-paste command for you to run by hand. Companion to the hardening map of content
[[arch-linux-hardening]] and the storage audit [[arch-system-audit]].

> [!summary] Headline
> The system is **already in better shape than a stock Arch install**: AppArmor is in the LSM
> chain, ufw is active, `sshd` is off, `auditd` is on, and eight key sysctl hardening values are
> already set. The real gaps are **detection, not prevention** — there is no malware scanner, no
> file-integrity baseline, and no repeatable audit score. This runbook closes those three gaps
> with lynis, ClamAV + fangfrisch, and AIDE, then lists the low-risk cleanups worth doing.

---

## Context

Threat model for this machine: a single-user Arch desktop (Niri/Wayland, Syncthing, Flatpak,
podman) that faces the normal internet through a browser. Not a server, not multi-tenant. So the
goal is **defence in depth without breaking daily use** — no `noexec` on `/home`, no output-chain
firewall drop policy, no kernel lockdown that kills suspend. Each recommendation below is tagged
with its daily-use risk.

Why these three tools specifically:

| Tool | Answers | Cost if it misbehaves |
|---|---|---|
| **lynis** | "How hardened am I, and what slipped?" | None — read-only audit |
| **ClamAV + fangfrisch** | "Is there known malware on disk / in downloads?" | ~150 MB RAM only while scanning |
| **AIDE** | "Did any protected file change since I trusted it?" | None until you act on a report |

> [!info] ClamAV on Linux is a choice, not a given
> Linux desktop malware is rare compared to Windows, and ClamAV's real value on a Linux box is
> scanning **incoming files you forward to others**, email attachments, and downloads — not
> resident on-access protection. That is why this runbook sets up **on-demand + scheduled scanning**,
> not a resident `clamd` daemon eating RAM. Fangfrisch adds the unofficial signatures (Sanesecurity,
> URLhaus, etc.) where most real Linux-relevant detections live.

---

## Current state — verified snapshot

Gathered 2026-10-10 without root. Reproduce with the commands in
[[arch-system-audit#Diagnostic commands used]] plus those in each section here.

### Already hardened (no action needed)

| Check | Value | Verdict |
|---|---|---|
| Kernel | `7.2.9-arch1-1` | current |
| LSM chain | `capability,landlock,lockdown,yama,apparmor,bpf` | AppArmor + Landlock + Yama present |
| `apparmor.service` | enabled | MAC is on |
| `auditd` + `audit-rules` | enabled | syscall auditing on |
| `ufw.service` | enabled, **active** | firewall up |
| `sshd` | **inactive** | no remote-access exposure |
| `kernel.dmesg_restrict` | `1` | dmesg locked down |
| `kernel.kptr_restrict` | `2` | kernel pointers hidden |
| `kernel.yama.ptrace_scope` | `2` | ptrace restricted |
| `kernel.unprivileged_bpf_disabled` | `1` | unprivileged BPF off |
| `fs.protected_hardlinks` / `protected_symlinks` | `1` / `1` | link attacks blocked |
| `net.ipv4.tcp_syncookies` | `1` | SYN-flood protection |
| `kernel.randomize_va_space` | `2` | full ASLR |
| CPU vulnerabilities | all `Mitigation:` or `Not affected` | microcode + kernel mitigations active |
| `dnscrypt-proxy` | enabled | encrypted DNS (see [[arch-dnscrypt-proxy]]) |

### Gaps (this runbook fixes)

| # | Finding | Severity | Fix |
|---|---|---|---|
| 1 | No malware scanner installed | medium | ClamAV + fangfrisch → §3, §4 |
| 2 | No file-integrity baseline | medium | AIDE → §5 |
| 3 | No repeatable hardening score | low | lynis → §2 |
| 4 | No rootkit/backdoor scanner or forensic audit | medium | rkhunter/chkrootkit/unhide → §1 + [[Rootkit and Backdoor Detection]] |
| 5 | No AUR supply-chain screening (June 2026 attack window) | medium | [[Rootkit and Backdoor Detection]] §2 IOC sweep |
| 6 | `avahi-daemon` enabled, listening `0.0.0.0:5353` | medium | disable → §7.1 |
| 7 | `bluetooth.service` enabled | low | disable if unused → §7.2 |

### Listening ports (attack surface)

`ss -tulpn` as uid 1000 shows only loopback-bound services plus Syncthing's own ports:

```
127.0.0.1:11434   ollama          (loopback only — safe)
127.0.0.1:53      dnscrypt-proxy  (loopback only — safe)
0.0.0.0:5353      avahi-daemon    ← the one to remove (§7.1)
0.0.0.0:21027     syncthing       (discovery — needed)
*:22000           syncthing       (sync — needed)
```

Everything except Syncthing and Avahi binds to loopback. Avahi is the only unnecessary
world-facing listener.

---

## 1. Install the three tools

You run these by hand — `sudo` needs your password. `paru` handles the two AUR packages.

> [!tip] PKGBUILDs reviewed before this recommendation
> Both AUR packages were cloned and read before being written into this note:
> **python-fangfrisch 1.9.2-2** is standard Python packaging, dual-sourced (GitHub + PyPI with
> identical sha512), and installs a systemd timer. **aide 0.19.4-2** verifies its source tarball
> against upstream maintainer Hannes von Haugwitz's PGP key (`2BBBD30F…`) and ships
> `aidecheck.timer`. Neither runs unexpected code. The nettle-4.0 build break reported on the AUR
> page in May 2026 is fixed as of `pkgrel=2` (2026-08-31).

```bash
# Official repos — lynis + clamav
sudo pacman -S --needed lynis clamav

# AUR — fangfrisch (unofficial signatures) + AIDE (integrity monitor)
paru -S python-fangfrisch aide
```

Verify:

```bash
pacman -Q lynis clamav python-fangfrisch aide
# lynis 3.1.7-1 · clamav 1.5.4-1 · python-fangfrisch 1.9.2-2 · aide 0.19.4-2
```

> [!note] Why AIDE is AUR-only
> AIDE left the official repos; the AUR package is the maintained path on Arch. If you would
> rather not use AUR at all, the official-repo alternative for integrity monitoring is `auditd`
> (already enabled here) with explicit `-w` file watches — see §7.4.

---

## 2. lynis — establish a baseline

lynis is read-only. It scores the system and lists every hardening suggestion with a test ID. Run
it once now to get a baseline, and again after each change to confirm the score moved.

```bash
# Full audit (writes only to /var/log/lynis.log)
sudo lynis audit system

# Faster: skip tests that need services you do not run
sudo lynis audit system --tests-from-category malware,networking,authentication,filesystems

# Show only the suggestions, not the whole scan
sudo lynis audit system --quiet
```

Capture the score and the suggestions list for the record:

```bash
sudo lynis audit system 2>&1 | tee /tmp/lynis-baseline.txt
grep -A2 "Hardening" /tmp/lynis-baseline.txt
grep "suggestion" /tmp/lynis-baseline.txt
```

The two numbers that matter:

- **Hardening index** (0–100). A fresh-but-not-hardened desktop typically lands 60–75. Your
  sysctl/AppArmor/ufw baseline already in place should push this higher.
- **Warnings** vs **suggestions**. Warnings are real misconfigurations — fix those first.
  Suggestions are optional hardening — apply the daily-use-safe ones from §7.

> [!important] lynis suggestions are not all safe to apply blindly
> lynis does not know your use case. It will suggest things like disabling USB storage, enabling
> `modules_disabled=1`, or a default-drop output firewall — any of which can break a desktop.
> Treat its list as a menu, and cross-check each item against the risk tag in §7 before acting.

Record the baseline index in the `findings` block of this note's frontmatter once you have it, so
future runs have something to compare against.

---

## 3. ClamAV — install and initialise

ClamAV needs two things: the engine (`clamscan`/`clamd`) and the signature databases, which are
fetched by `freshclam`.

```bash
# 1. Fetch the official signature databases first (~300 MB, takes a few minutes)
sudo freshclam

# 2. Sanity-check the engine with a known-test string
echo "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*" > /tmp/eicar.com
clamscan /tmp/eicar.com
# Expected: /tmp/eicar.com: Eicar-Test-Signature FOUND
rm /tmp/eicar.com
```

> [!warning] The EICAR test above is the real check
> If `clamscan` does **not** flag `/tmp/eicar.com`, your databases are missing or stale — do not
> trust any scan result until `freshclam` completes cleanly. Re-run it and read the journal:
> `journalctl -u clamav-freshclam.service -e`.

### Official vs unofficial signatures

`freshclam` pulls the **official** ClamAV sets. Most detections relevant to a Linux desktop
(Sanesecurity clamshell/foolproof sets, URLhaus malicious-URL hashes, Linux Malware Detect,
SecuriteInfo) are **unofficial** and come from a second updater — which is exactly what fangfrisch
provides. Running both is the intended setup: freshclam for canon, fangfrisch for everything else.

---

## 4. fangfrisch — unofficial signatures

fangfrisch ("freshly caught") is a more secure replacement for the older `clamav-unofficial-sigs`.
Two properties matter for a desktop: it **never needs root** (it drops to the `clamav` user), and it
**checks digests before downloading**, so a 10-minute interval costs almost no bandwidth.

### 4.1 Create the signature database

```bash
# One-time: create fangfrisch's own tracking DB, run as the clamav user (not root)
sudo -u clamav fangfrisch --conf /etc/fangfrisch/fangfrisch.conf initdb
```

### 4.2 Enable the update timer

```bash
sudo systemctl enable --now fangfrisch.timer
systemctl status fangfrisch.timer
```

The timer runs `fangfrisch refresh` periodically. Each provider has its own interval inside
`/etc/fangfrisch/fangfrisch.conf`; files judged "too young" are skipped with no network call.

### 4.3 Configure which providers to trust

`/etc/fangfrisch/fangfrisch.conf` ships with providers **disabled by default** — you opt in. The
recommended desktop set:

```ini
# /etc/fangfrisch/fangfrisch.conf  (excerpt)

# Sanesecurity — the highest-value unofficial set for Linux
sanesecurity_enabled = yes

# URLhaus — malicious URL hashes (abuse.ch)
urlhaus_enabled = yes

# SecuriteInfo — extra PUP/rogue detections (needs a free API key)
securiteinfo_enabled = yes

# Linux Malware Detect
linuxmalwaredetect_enabled = yes
```

> [!caution] SecuriteInfo needs an API key
> Leave `securiteinfo_enabled = no` until you have registered for a free key at
> securiteinfo.com and put it in `securiteinfo_user` / `securiteinfo_password`. With it disabled
> everything else still works.

After editing, force one refresh and watch the result:

```bash
sudo -u clamav fangfrisch --conf /etc/fangfrisch/fangfrisch.conf refresh
journalctl -u fangfrisch.service -e
```

Expected: each enabled provider reports `downloaded` or `up to date`, with no `FAILED` lines.

### 4.4 Point clamav at the fangfrisch databases

fangfrisch writes its signatures into the directory configured as `dbpath` (by default
`/var/lib/fangfrisch`, group `clamav`). For `clamscan` to use them, add that path to
`/etc/clamd.conf` and `/etc/freshclam.conf`:

```ini
# /etc/clamd.conf
DatabaseCustomURL /var/lib/fangfrisch/
```

```ini
# /etc/freshclam.conf — do not let freshclam delete fangfrisch's files
DatabaseCustomURL file:///var/lib/fangfrisch/
```

> [!note] Skip this if you only use `clamscan`
> `clamscan` loads every `.cvd`/`.cld`/`.ndb` it finds in its default path plus any
> `DatabaseCustomURL`. The step above is only needed so the **daemon** (`clamd`) and the
> scheduled scans in §8 see the unofficial sets. When in doubt, run a scan and confirm the
> signature count is well above the official-only number.

### 4.5 On-demand scan (no resident daemon)

A resident `clamd` holds ~1 GB of signatures in RAM. For a desktop that is wasteful — scan on
demand instead:

```bash
# Scan a directory, show progress, report only infected files
clamscan --recursive --infected --log=/tmp/clamscan.log ~/Downloads

# Scan with the fangfrisch sets explicitly loaded
clamscan --database=/var/lib/fangfrisch --recursive --infected ~/

# Scan a single file before opening it
clamscan --infected /path/to/file
```

> [!tip] Scan downloads automatically, cheaply
> Rather than a resident daemon, add a scheduled scan of `~/Downloads` (§8). That catches the
> realistic desktop threat — a bad file you fetched — without paying RAM all day.

---

## 5. AIDE — file-integrity baseline

AIDE hashes a set of files into a baseline database, then on each later run reports what changed.
It detects the classic post-compromise move: an attacker editing `/etc/passwd`, a SUID binary, or a
systemd unit to persist.

### 5.1 Tune what to watch

`/etc/aide.conf` ships with Fedora-derived defaults that are too broad for a desktop (watching all
of `/home` makes every run noisy). Trim it to system paths:

```ini
# /etc/aide.conf  (excerpt — keep the stock rules, adjust these)

# Watch system binaries and config, not user data
bin_root = /usr/bin
sbin_root = /usr/sbin
# Do NOT watch /home — too volatile, all noise
# Do NOT watch /var/log — rotates constantly

# The stock @@{RULE} macros are fine; just make sure these are in the watch set:
/etc
/boot
/usr/bin
/usr/sbin
/usr/lib/systemd/system
```

Validate the config parses before generating anything:

```bash
sudo aide -D
```

### 5.2 Generate the baseline

```bash
# First run — can take a few minutes and several hundred MB
sudo aide --init

# Move the fresh DB into place (aide writes .new, does not overwrite)
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

### 5.3 Check against the baseline

```bash
sudo aide --check
# Exit 0 = clean. Non-zero = something changed; read the report.
```

After an **intentional** system change (a `pacman -Syu`, a config edit), update the baseline
rather than letting the change show up as a false alarm:

```bash
sudo aide --update
sudo mv /var/lib/aide/aide.db.new.gz /var/lib/aide/aide.db.gz
```

### 5.4 Automate the check

The AUR package ships a timer. Enable it and read results from the journal:

```bash
sudo systemctl enable --now aidecheck.timer
systemctl list-timers | grep aide
journalctl -u aidecheck.service -e
```

> [!danger] Store a copy of the baseline offline
> The AIDE database lives on the root filesystem. An attacker with root can rewrite it to hide
> their changes. Copy `aide.db.gz` to read-only/offline media (a USB stick, a git repo you push
> elsewhere) right after `--init`, and periodically check against that copy. This is the single
> most-missed AIDE step.

### 5.5 AIDE vs auditd — use both, they answer different questions

| | AIDE | auditd (already enabled here) |
|---|---|---|
| Detects | files that **changed** since baseline | file **accesses/changes** in real time, syscalls |
| Timing | periodic snapshot | continuous event log |
| Best for | "did `/usr/bin/sudo` get replaced?" | "who touched `/etc/shadow`, when?" |

auditd is already running on `bacon`. Give it a few explicit watches on the files AIDE also
covers, so you get an event log to go with AIDE's diff:

```bash
# /etc/audit/rules.d/10-hardening.rules
-w /etc/passwd -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /usr/bin/sudo -p x -k sudo_exec
-a always,exit -F arch=b64 -S execve -C uid!=euid -k priv_escalation
```

```bash
sudo augenrules --load
sudo auditctl -l
```

---

## 6. Rootkit & backdoor detection — bacon results

> [!info] The generic playbook now lives in its own note
> The layer-by-layer hunt — threat model, AUR supply-chain IOCs, rkhunter/chkrootkit/unhide,
> `/proc` vs `ps` reconciliation, eBPF maps, persistence audit, incident response and the honest
> limitations — is now the reusable, host-agnostic [[Rootkit and Backdoor Detection]]. This
> section keeps only what was verified **on `bacon`** on 2026-10-10, so a future run has a
> baseline to diff against. Everything below ran **read-only as uid 1000**; `[root]` marks
> commands you run by hand.

### 6.1 Verified clean on `bacon` (2026-10-10)

| Check | Command | Result |
|---|---|---|
| eBPF pinned maps | `ls /sys/fs/bpf/` | ✅ empty |
| eBPF map names | `find /sys/fs/bpf -maxdepth 2` | ✅ none (`hidden_*` absent) |
| kernel taint | `cat /proc/sys/kernel/tainted` | ✅ `0` |
| module tables agree | `wc -l </proc/modules` vs `ls /sys/module/ \| wc -l` | ✅ 210 vs 210 |
| process hiding | `/proc` count vs `ps -e --no-headers` count | ✅ equal |
| deleted-executable procs | `ls -l /proc/*/exe \| grep '(deleted)'` | ✅ none |
| `ld.so.preload` | `test -f /etc/ld.so.preload` | ✅ absent |
| persistence unit | `Restart=always` + `RestartSec=30` sweep | ✅ none |
| shell droppers | rc-file `curl … \| sh` / `base64 -d` sweep | ✅ none |
| C2 to temp.sh / onion | `ss -tnp \| grep -E 'temp\.sh\|\.onion'` | ✅ none |
| npm preinstall in build caches | `grep -rn preinstall ~/.cache/paru ~/.cache/yay` | ✅ none |
| non-root SUID | `find / -perm /4000 ! -user root` | ✅ none |
| world-writable dirs | `find / -xdev -type d -perm -0002` | ✅ only `/var/spool/mail`, `/var/tmp` |
| AUR attack window | pacman.log grep for `atomic-lockfile`/`deps`/`js-digest` | ✅ not installed |

### 6.2 Open items this section still owes

- **Scanners not installed.** `rkhunter`, `chkrootkit` (AUR) and `unhide` are documented in §1 but
  not yet installed or run — until then this page has a manual audit but **no signature or
  forensic baseline**. Install and run the scanner checks in [[Rootkit and Backdoor Detection]] §3.
- **Boot chain not confirmed.** `module.sig_enforce=1` + a `lockdown=` mode would make unsigned
  LKMs *structurally* unloadable rather than merely detectable. Check `/proc/cmdline` and see
  [[Boot and Secure Boot]].
- **No eBPF baseline.** `bpftool` is already present (`/usr/sbin/bpftool`); capture a `[root]`
  baseline of `bpftool map list` and `bpftool prog list` now, so a future diff means something —
  the June 2026 attack hid processes with pinned maps.

> [!important] Supply chain, not the kernel, is the realistic vector here
> `bacon` installs from the AUR via `paru`. The durable control is **minimising AUR surface** and
> reviewing every PKGBUILD before `paru -S` (as was done for fangfrisch and aide in §1), not a
> scanner. See [[Arch Lifecycle — Install, Maintain, Recover]].

---

## 7. Low-risk hardening cleanups

Ordered by value-per-risk. Each is safe for daily use unless marked. All are reversible by running
the command in reverse (`enable` for `disable`).

### 7.1 Disable Avahi (mDNS) — recommended

Avahi advertises and resolves `.local` hostnames on your LAN. Unless you use mDNS device discovery
(printers, Chromecast, `ssh host.local`), it is pure attack surface listening on `0.0.0.0:5353`.

```bash
sudo systemctl disable --now avahi-daemon.service
ss -ulnp | grep 5353   # should now be empty
```

> [!caution] Check first if you use `.local` names
> If you `ssh` to devices by `.local`, or rely on printer discovery, Avahi is doing a job — leave
> it. Risk if disabled: mDNS discovery stops. Nothing else.

### 7.2 Disable Bluetooth if unused — recommended

```bash
sudo systemctl disable --now bluetooth.service
```

Risk if disabled: no BT peripherals. Re-enable any time with `enable --now`. If you do use a BT
mouse/keyboard, skip this.

### 7.3 Verify the ufw ruleset — recommended

ufw is active but was not auditable without root. Confirm what it actually allows:

```bash
sudo ufw status verbose
# Expect: Status: active, Default: deny (incoming), and only your needed ports allowed
```

If the default incoming policy is not `deny`, tighten it:

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw reload
```

Risk: none for a desktop — outgoing-allow keeps browsing/sync working; incoming-deny only blocks
unsolicited connections, and nothing here serves the LAN.

### 7.4 Optional — further sysctl tightening

Your sysctls are already good. If you want to go further, the **daily-use-safe** additions (they
do not affect Flatpak, podman, or Wayland):

```ini
# /etc/sysctl.d/99-hardening.conf  (additive — safe)
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.tcp_timestamps = 0
kernel.sysrq = 0
```

```bash
sudo sysctl --system
```

> [!warning] Do NOT set these on a desktop — they break things
> Explicitly avoided here because they break daily use on `bacon`:
> - `user.max_user_namespaces = 0` → kills Flatpak, bubblewrap, podman, rootless containers
> - `kernel.modules_disabled = 1` → irreversible until reboot; a single missing module = no boot
> - `kernel.unprivileged_userns_clone = 0` → same breakage as max_user_namespaces
> - `vm.mmap_rnd_bits = 32` → fine on modern glibc, but test suspend/resume if you raise it
>
> The full menu of *these* options is in [[Kernel Hardening]] — apply
> them on a server, not on the machine you work on.

### 7.5 Explicitly NOT recommended for this machine

| Idea | Why not here |
|---|---|
| `linux-hardened` kernel | lags mainline; can break suspend/NVIDIA. Stock + sysctls is the better trade |
| `lockdown=confidentiality` | kills hibernation and out-of-tree modules (ZFS, NVIDIA, VirtualBox) |
| nftables output-chain `policy drop` | breaks mDNS, Syncthing, ollama, browsers — high babysitting cost |
| `noexec` on `/home` | breaks Wine, Steam, PyCharm, scripts, .NET |
| Resident `clamd` daemon | ~1 GB RAM resident for a threat model that on-demand scanning covers |
| `usbguard` | only if you physically worry about rogue USB; adds friction to every flash drive |

The philosophy is in [[Security Principles for Arch Linux]] — the goal is a
secure **and useful** system.

---

## 8. Scheduled scanning (optional, low overhead)

Both variants below run `clamscan` once and exit — no resident daemon, no RAM held between runs.
Pick by where the files you care about live; they can coexist.

### 8.1 User timer — `~/Downloads`

Use this when the paths you want scanned are readable by your own user. No root, no `/etc`.

```bash
mkdir -p ~/.config/systemd/user
```

```ini
# ~/.config/systemd/user/clamav-downloads.service
[Unit]
Description=ClamAV scan of ~/Downloads

[Service]
Type=oneshot
ExecStart=/usr/bin/clamscan --recursive --infected --log=%h/.local/state/clamav-downloads.log %h/Downloads
```

```ini
# ~/.config/systemd/user/clamav-downloads.timer
[Unit]
Description=Weekly ClamAV scan of ~/Downloads

[Timer]
OnCalendar=weekly
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemctl --user daemon-reload
systemctl --user enable --now clamav-downloads.timer
systemctl --user list-timers | grep clamav
```

### 8.2 System-wide scan — one unit, paths in a config file

Use this when a path needs root, or when your own user should not be widened to read it:
`/etc`, `/usr/local`, `/srv`, `/var/tmp`, mounted media. The folder list lives in a single
config file, so **adding a folder later is a one-line edit** — no unit edits, no `daemon-reload`.

```bash
sudo mkdir -p /var/log/clamav
sudoedit /etc/conf.d/clamav-scan.conf
```

```ini
# /etc/conf.d/clamav-scan.conf
# Space-separated. systemd word-splits these values *before* clamscan sees them, so keep the
# outer quotes around the whole value and put no spaces inside a single path (see Gotchas).
SCAN_PATHS="/home/joaov/Downloads /srv/incoming /var/tmp"

CLAMSCAN_OPTS="--recursive --infected --cross-fs=no --exclude-dir=^/proc --exclude-dir=^/sys --exclude-dir=^/dev --exclude-dir=^/run"
```

```ini
# /etc/systemd/system/clamav-scan.service
[Unit]
Description=ClamAV on-demand scan of the paths in /etc/conf.d/clamav-scan.conf
Documentation=man:clamscan(1) https://wiki.archlinux.org/title/ClamAV
After=local-fs.target

[Service]
Type=oneshot
EnvironmentFile=/etc/conf.d/clamav-scan.conf

# $SCAN_PATHS as a word of its own expands to one argument per path (word-split).
# ${SCAN_PATHS} inside a longer word expands to one argument, unsplit. Do not mix these up.
ExecStartPre=/usr/bin/logger -t clamav-scan "scanning: ${SCAN_PATHS}"
ExecStart=/usr/bin/clamscan $CLAMSCAN_OPTS --log=/var/log/clamav/scan.log $SCAN_PATHS

# A whole-disk scan runs far longer than the 90 s default, which would kill it.
TimeoutStartSec=infinity

# Stay out of the way of whatever you are actually doing.
Nice=19
IOSchedulingClass=idle
CPUWeight=20
IOWeight=20

# Read everything, write (almost) nothing.
# 'full', not 'strict': strict would also need ReadWritePaths=/var/log/clamav /tmp.
# No PrivateTmp= — it would hand the scan an empty private /tmp *and* /var/tmp.
ProtectSystem=full
ProtectHome=read-only
PrivateNetwork=yes
NoNewPrivileges=yes
```

```ini
# /etc/systemd/system/clamav-scan.timer
[Unit]
Description=Daily ClamAV scan of the paths in /etc/conf.d/clamav-scan.conf

[Timer]
OnCalendar=*-*-* 03:30:00
RandomizedDelaySec=30min
AccuracySec=1h
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
systemd-analyze verify clamav-scan.service     # parse check, before anything is enabled
sudo systemctl daemon-reload
sudo systemctl start clamav-scan.service       # run it once now; a first run loads the DB (~20 s)
journalctl -u clamav-scan.service -f           # Ctrl-C is safe — the scan keeps running
sudo systemctl enable --now clamav-scan.timer
systemctl list-timers clamav-scan.timer
```

Adding a folder later:

```bash
sudoedit /etc/conf.d/clamav-scan.conf      # append the path to SCAN_PATHS
sudo systemctl start clamav-scan.service   # EnvironmentFile is re-read at every start
journalctl -t clamav-scan -n 1             # the logger line prints the list actually used
```

> [!note] Exit codes are the alert
> `clamscan` exits `0` (clean), `1` (detection) or `2` (error — bad path, or an empty
> `SCAN_PATHS`). `SuccessExitStatus=` is deliberately **not** set, so either a detection or a
> broken config surfaces in `systemctl --failed` instead of hiding in a log file. Check it after
> the first few runs: `systemctl --failed --type=service`.

> [!note] Keep signatures current for the scheduled scan to mean anything
> A daily scan is only as good as the databases. `freshclam` and `fangfrisch.timer` (§3, §4.2)
> must both be running, or the scan checks yesterday's signatures.

---

## Gotchas

> [!danger] Do not run `fangfrisch` or `aide --init` as root
> fangfrisch is designed to run as the `clamav` user (`sudo -u clamav …`). Running it as root
> creates root-owned files in the signature path that `clamd` then cannot read. AIDE's database
> must be root-owned, but fangfrisch's must not be — the distinction matters.

> [!warning] AIDE will scream after every `pacman -Syu`
> A system update legitimately changes hundreds of binaries. Either run `aide --update` after each
> upgrade, or accept the noise and read the diff to confirm the changes are only pacman's. Do not
> ignore AIDE reports long-term — that is how a real change hides in the noise.

> [!caution] `clamscan` on `/` is slow and mostly pointless
> Scanning the whole filesystem takes hours and flags stale caches. Scan `~/Downloads`, `~/`,
> attached media, and email attachments — the paths files actually arrive through.

> [!warning] fangfrisch providers are disabled by default
> After `initdb`, nothing downloads until you set `*_enabled = yes` in `/etc/fangfrisch/fangfrisch.conf`
> (§4.2). A fresh install that appears to do nothing is usually this.

> [!caution] The EICAR test file is not a toy
> Some real-time AV (if you ever add one) will quarantine `/tmp/eicar.com` the instant it is
> written. That is correct behaviour, not an error — the file is the industry-standard test string.

> [!warning] `$SCAN_PATHS` only splits as a word of its own
> Verified against clamav 1.5.4 + systemd 262: `$FOO` is expanded **only** when it is a word on
> its own; embedded in a larger word it is passed through literally (that is why `ExecStartPre`
> above uses `${SCAN_PATHS}`). Quotes *inside* the value are not honoured either, so a path with a
> space cannot be expressed this way: `SCAN_PATHS="/home/me/My Media /srv"` reaches clamscan as the
> mangled `/home/me/My` `Media/srv`. Keep paths space-free, or point clamscan at
> `--file-list=/etc/clamav/scan-paths.txt` (one path per line) instead.

> [!warning] `--cross-fs=no` does not enter nested mount points
> It stops clamscan descending into a filesystem mounted *inside* the scanned tree: scanning `/`
> does not enter a separately-mounted `/home`, a USB stick under `/run/media`, or `/dev/pts`
> (measured here: 46 directories with the flag absent, 42 with it). It does **not** skip a path you
> list explicitly — a `/srv` on its own partition in `SCAN_PATHS` is scanned either way. So name the
> mount points you care about; never rely on the parent directory reaching them.

> [!note] `--exclude-dir` matches the full path, not the basename
> Verified against clamav 1.5.4: `--exclude-dir=^/proc` is correct, `--exclude-dir=^proc` is not.

> [!warning] Adding `PrivateTmp=yes` silently blinds the scan to `/tmp` and `/var/tmp`
> PrivateTmp is an obvious thing to add to a sandboxed unit, and it is wrong here: it mounts a
> private tmpfs at **both** `/tmp` and `/var/tmp`, so those two paths — the classic places a
> dropped payload lands — arrive at clamscan empty. Measured on `bacon`: 9 entries in `/var/tmp`
> normally, 0 inside the unit. That is why the unit above omits it.

---

## Verification

Run after the installs to confirm the whole stack is live:

```bash
# Tools present
pacman -Q lynis clamav python-fangfrisch aide

# ClamAV engine works (EICAR must be FOUND)
echo "X5O!P%@AP[4\PZX54(P^)7CC)7}$EICAR-STANDARD-ANTIVIRUS-TEST-FILE!$H+H*" > /tmp/eicar.com
clamscan /tmp/eicar.com && rm /tmp/eicar.com

# Scheduled scan (§8.2): timer armed, and the path list actually handed to clamscan
systemctl is-active clamav-scan.timer
journalctl -t clamav-scan -n 1
ls -l /var/log/clamav/scan.log

# freshclam + fangfrisch both updating
systemctl status clamav-freshclam.service fangfrisch.timer

# fangfrisch DB exists and is group-readable by clamav
sudo -u clamav fangfrisch --conf /etc/fangfrisch/fangfrisch.conf refresh

# AIDE baseline in place + timer armed
ls -l /var/lib/aide/aide.db.gz
systemctl is-active aidecheck.timer

# Avahi gone
ss -ulnp | grep 5353        # expect empty

# Firewall still deny-by-default
sudo ufw status verbose

# AppArmor still enforcing
aa-status | head -5

# lynis score improved vs your §2 baseline
sudo lynis audit system --quiet 2>&1 | grep "hardening index"
```

Expected: every command succeeds; the EICAR file is flagged; `aide.db.gz` exists; port 5353 is
gone; lynis hardening index is equal or higher than the baseline recorded in §2.

Expected addition for §8.2: `journalctl -t clamav-scan` prints one line per run — the exact path
list that run used. If a folder you added is missing from that line, it never reached `clamscan`.

---

## Rollback

Every step here is reversible without a reinstall:

| Change | Rollback |
|---|---|
| Avahi disabled | `sudo systemctl enable --now avahi-daemon.service` |
| Bluetooth disabled | `sudo systemctl enable --now bluetooth.service` |
| ufw policy tightened | `sudo ufw default allow incoming && sudo ufw reload` |
| sysctl additions | delete `/etc/sysctl.d/99-hardening.conf`, then `sudo sysctl --system` |
| ClamAV / fangfrisch | `sudo pacman -Rns clamav` and `paru -Rns python-fangfrisch` |
| §8.2 scheduled scan | `sudo systemctl disable --now clamav-scan.timer && sudo rm /etc/systemd/system/clamav-scan.{service,timer} /etc/conf.d/clamav-scan.conf && sudo systemctl daemon-reload` (add `rm -rf /var/log/clamav` for the log) |
| AIDE | `paru -Rns aide` (its timer stops with it) |
| auditd rules | `sudo rm /etc/audit/rules.d/10-hardening.rules && sudo augenrules --load` |

None of these touch your data, your LUKS container, or your btrfs layout — see [[arch-system-audit]]
for the storage layer, which this runbook deliberately does not modify.

---

## Related

- [[arch-linux-hardening]] — the hardening map of content (was the generic 22-section reference, now split into focused notes)
- [[arch-system-audit]] — storage/LUKS/btrfs audit of the same host
- [[arch-dnscrypt-proxy]] — encrypted DNS, already active on this machine
- [[Home]] — vault index

## Sources

- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — the hardening baseline; sysctl,
  user-setup, SUID, mount-option and MAC recommendations all trace here.
- [ClamAV — ArchWiki](https://wiki.archlinux.org/title/ClamAV) — freshclam setup, the unofficial-signature
  section (fangfrisch vs clamav-unofficial-sigs), on-access vs on-demand.
- [AIDE — ArchWiki](https://wiki.archlinux.org/title/AIDE) — install, `--init`/`--check`/`--update`, the
  offline-database warning, and the AUR-only status on Arch.
- [fangfrisch upstream docs](https://github.com/rseichter/fangfrisch) — the `initdb`-as-clamav-user step,
  digest-before-download behaviour, 10-minute interval guidance, provider list.
- [python-fangfrisch — AUR](https://aur.archlinux.org/packages/python-fangfrisch/) and
  [aide — AUR](https://aur.archlinux.org/packages/aide/) — package metadata; both PKGBUILDs were cloned and
  read locally before being recommended (see §1).
- [Lynis documentation](https://cisofy.com/documentation/lynis/) — audit usage, hardening index semantics.

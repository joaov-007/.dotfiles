---
title: "Rootkit and Backdoor Detection"
aliases:
  - Rootkit and Backdoor Detection
  - rootkit detection
  - rootkit hunting
  - backdoor detection
  - rkhunter
  - chkrootkit
  - unhide
description: >-
  The runtime-state lens that file-integrity and signature scanners miss: how a rootkit hides in
  the kernel module table, eBPF maps, the process list, listeners or preload libraries; the three
  scanners that cover the known cases; a layer-by-layer manual hunt; how to read the noise; and
  what to do — and not do — once you find something.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - rootkit
  - backdoor
  - forensics
  - hids
  - eBPF
  - malware-scanning
  - monitoring
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Host-agnostic rootkit and backdoor detection on Arch Linux: threat model, scanners, manual
  runtime forensics, incident response and limitations. Machine-specific verified results live
  in [[arch-hardening-runbook]].
platform:
  - arch-linux
  - linux-kernel
keywords:
  - LKM rootkit
  - eBPF rootkit
  - hidden_pids
  - bpftool map list
  - /sys/fs/bpf
  - /proc/sys/kernel/tainted
  - /proc/modules
  - process hiding
  - unhide proc
  - ld.so.preload
  - pacman -Qkk
  - SUID backdoor
  - persistence systemd cron udev
  - reverse shell
  - AUR supply chain attack 2026
  - atomic-lockfile
  - rkhunter --propupd
  - chkrootkit lkm
  - incident response
related:
  - "[[Monitoring, Integrity and Auditing]]"
  - "[[Arch Lifecycle — Install, Maintain, Recover]]"
  - "[[Kernel Hardening]]"
  - "[[Security Principles for Arch Linux]]"
  - "[[Arch Linux Security Hardening]]"
cssclasses:
  - wide-table
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Rootkit and Backdoor Detection

> [!summary] One-paragraph answer
> AIDE watches **files on disk**; ClamAV matches **known-bad signatures**. A rootkit lives in
> **runtime state** — the kernel module table, eBPF maps, the process list, listening sockets,
> preload libraries — and can pass both cleanly. This note is the third lens: find things that are
> **hiding**, not just things that changed. On an Arch desktop the realistic entry point is a
> **malicious PKGBUILD**, not a bespoke kernel rootkit, so supply-chain checks come first.

## Context

Open this when something "feels wrong", after a suspicious AUR install, or as a periodic sanity
check. It assumes you have already run the file-integrity and logging controls in
[[Monitoring, Integrity and Auditing]]; this note is what those cannot see.

> [!info] Nothing here is run for you
> The commands are safe to run by hand. Anything needing root is marked `[root]`. Read the
> clean-vs-bad signal before interpreting output — the tools have loud false positives.

## Details

### 1. Threat model — five places a rootkit hides

| Class | Hides in | On-disk artifact? | Caught by |
|---|---|---|---|
| **LKM rootkit** | module table, hooked syscalls | sometimes a `.ko` | §5, rkhunter, chkrootkit `lkm` |
| **eBPF rootkit** | eBPF maps/progs pinned in `/sys/fs/bpf` | often none | §6 — *nothing else catches this* |
| **Userspace rootkit** | trojaned `ls`/`ps`/`ss`, `LD_PRELOAD` | patched binary | §7, AIDE, `pacman -Qkk` |
| **Persistence / backdoor** | systemd, cron, udev, EFI | a unit or script | §8 |
| **Network backdoor** | bind/reverse shell, covert listener | often none | §9 |

### 2. Supply chain first — the real desktop threat

The most likely backdoor on an Arch desktop is a **malicious PKGBUILD**, not a kernel rootkit.
The June 2026 AUR supply-chain attack shipped credential-stealing malware plus an eBPF rootkit
through compromised packages. Because it is Arch-specific and recent, screen for it before
anything else.

| # | Indicator | Check (uid 1000) |
|---|---|---|
| 1 | eBPF rootkit pinned maps | `ls /sys/fs/bpf/` |
| 2 | maps named `hidden_pids`/`hidden_names`/`hidden_inodes` | `find /sys/fs/bpf -maxdepth 2` |
| 3 | backdoor unit `Restart=always` **and** `RestartSec=30` | see below |
| 4 | C2 to `temp.sh` or an onion host | `ss -tnp \| grep -E 'temp\.sh\|\.onion'` |
| 5 | shell droppers in rc files | `grep -rlE '(curl\|wget).*\| *(ba)?sh' ~/.bashrc ~/.zshrc /etc/profile.d/` |
| 6 | npm preinstall hook in build caches | `grep -rn preinstall ~/.cache/paru ~/.cache/yay 2>/dev/null` |

```bash
# IOC 3 — persistence unit with both markers
grep -rl "Restart=always" /etc/systemd/system/ ~/.config/systemd/ 2>/dev/null \
  | while read -r f; do grep -q "RestartSec=30" "$f" && echo "SUSPECT: $f"; done

# historical window (a package installed then and removed since still ran its build())
grep -nE 'installed (atomic-lockfile|deps|js-digest|lockfile-js)' /var/log/pacman.log
sed -n '/2026-06-09/,/2026-06-13/p' /var/log/pacman.log | grep -E 'installed|upgraded'
```

> [!important] The durable fix is not a scanner
> Minimise AUR surface: prefer `core`/`extra`, build in a clean chroot with `devtools`, review
> each PKGBUILD before `paru -S`, and never pipe a remote script to a shell. See
> [[Arch Lifecycle — Install, Maintain, Recover]].

### 3. The scanner toolkit

```bash
sudo pacman -S --needed rkhunter unhide   # official extra
paru -S chkrootkit                        # AUR
```

| Tool | Best at | Blind spot |
|---|---|---|
| **rkhunter** | known rootkit **signatures**, trojaned binaries, hidden files | heuristics only; no runtime hook inspection |
| **chkrootkit** | LKM presence, promiscuous-mode sniffers, bind shells | noisy false positives; shell-script based |
| **unhide** | **process/port hiding** — reconciles `/proc` vs `ps` | finds hiding, not the payload |

```bash
# rkhunter: baseline first, then check
sudo rkhunter --propupd
sudo rkhunter --check --sk
sudo rkhunter --check --summary

# chkrootkit: targeted tests, not everything
sudo chkrootkit lkm
sudo chkrootkit bindshell
sudo chkrootkit ifpromisc

# unhide: the zero-day catcher; needs no signature DB
sudo unhide proc
sudo unhide net
sudo unhide sys
```

> [!warning] `--propupd` is the step people skip
> Without a first `--propupd` baseline, rkhunter flags nearly every binary as "unknown" and the
> signal drowns. Re-run it only after a **known-clean** change, never to clear an unexplored
> warning.

> [!caution] chkrootkit's `sniffer`/`ps` tests lie on modern systems
> `NetworkManager`, `systemd-networkd` and `wpa_supplicant` open raw sockets legitimately and are
> reported as sniffers. Suppress with a regex and read
> `/usr/share/doc/chkrootkit/README.FALSE-POSITIVES.gz`:
> ```bash
> sudo chkrootkit -s '(systemd-networkd|NetworkManager|wpa_supplicant)'
> ```

### 4. LKM audit — kernel modules

```bash
lsmod                              # via /proc/modules
wc -l < /proc/modules              # /proc view
ls /sys/module/ | wc -l            # sysfs view — should be ≈ the /proc count
cat /proc/sys/kernel/tainted       # 0 = clean
```

The **taint flag** is the cheapest kernel-integrity signal on the system. Decode a non-zero value:

| Bit | Value | Meaning |
|---|---|---|
| 0 | 1 | proprietary module loaded |
| 1 | 2 | module force-loaded |
| 2 | 4 | forced unmount |
| 3 | 8 | signing forced off |
| 4 | 16 | runtime warning emitted |
| 9 | 512 | stage-2 module unload detected |

> [!note] Non-zero taint is not automatically an attack
> Loading an out-of-tree module (NVIDIA, ZFS, VirtualBox) legitimately sets it. The rule is:
> **know why** it is non-zero, and treat an *unexplained* value as a finding.

```bash
cat /proc/cmdline | grep -oE 'module\.sig_enforce=1|lockdown=[a-z]+'
# a lockdown mode + sig_enforce means unsigned LKMs cannot load at all — see [[Kernel Hardening]]
```

### 5. eBPF audit — the modern rootkit

eBPF rootkits run in-kernel without a `.ko`. The June 2026 attack used **pinned eBPF maps** named
`hidden_pids`, `hidden_names`, `hidden_inodes` to hide from `ps`. This is the class rkhunter and
chkrootkit are structurally blind to.

```bash
ls -la /sys/fs/bpf/                 # nothing pinned → no persistent eBPF rootkit
find /sys/fs/bpf -maxdepth 2 2>/dev/null

sudo bpftool map list               # maps and programs the kernel is running
sudo bpftool prog list
```

Look for map names matching `hidden_*`/`hide_*`, or `kprobe`/`tracepoint` programs you did not
load (a rootkit hooks `getdents64` to hide directory entries).

```ini
# remove the class for non-root attackers
kernel.unprivileged_bpf_disabled = 1
```

### 6. Process-hiding — reconcile `/proc` against `ps`

```bash
ls /proc | grep -E '^[0-9]+$' | wc -l     # raw kernel view
ps -e --no-headers | wc -l                 # tool view
# equal → clean. /proc > ps → something is filtering your process list.

ls -l /proc/*/exe 2>/dev/null | grep '(deleted)'
# any output = a process whose executable was removed/overwritten while running
```

> [!warning] The `(deleted)` check fires during a live `pacman -Syu`
> A binary being replaced under a running process shows as `(deleted)` legitimately. Do not run
> this mid-upgrade; treat output at any other time as suspicious.

### 7. File & binary integrity — the Arch-native check

```bash
pacman -Qkk                                            # every package's file counts
pacman -Qkk 2>&1 | grep -v ': 0 altered files'         # only deviations
pacman -Qo /usr/bin/* 2>/dev/null | grep -i 'error'   # files not owned by any package

find / -perm /4000 -type f ! -user root 2>/dev/null    # non-root SUID = red flag
find / -xdev -type d -perm -0002 2>/dev/null | grep -vE '^/(proc|sys|dev|tmp|run)'
```

"Altered files" under `/usr/bin` or `/usr/lib` means something modified a package-managed binary.
Reinstall the package, *then* investigate how it changed. This overlaps AIDE — see
[[Monitoring, Integrity and Auditing]].

### 8. Persistence audit — backdoors survive reboot

```bash
# systemd — system + user units
grep -rl "Restart=always" /etc/systemd/system/ ~/.config/systemd/ 2>/dev/null \
  | while read -r f; do grep -q "RestartSec=30" "$f" && echo "SUSPECT: $f"; done

# cron, autostart, pacman hooks, udev
ls -la /etc/cron.d/ /etc/cron.daily/ /var/spool/cron/ 2>/dev/null
ls ~/.config/autostart/ /etc/xdg/autostart/ 2>/dev/null
ls /etc/pacman.d/hooks/ 2>/dev/null
ls /etc/udev/rules.d/ 2>/dev/null

# ld.so.preload — library-injection rootkit's foothold
test -f /etc/ld.so.preload && cat /etc/ld.so.preload || echo "(absent — clean)"

# shell startup droppers
grep -rlE '(curl|wget).*\| *(ba)?sh|base64 +-d' ~/.bashrc ~/.zshrc ~/.profile /etc/profile.d/ 2>/dev/null
```

> [!danger] The two most-overlooked persistence points
> **`/etc/ld.so.preload`** injects a library into *every* dynamically-linked program (how a
> userspace rootkit survives even after its binary is deleted). **pacman hooks** run attacker
> code as root the next time you touch pacman — so a "harmless" `pacman -Syu` becomes the trigger.

### 9. Network backdoor

```bash
ss -tulpn                 # every listener + owning process
ss -tnp                   # every ESTABLISHED connection + process
ip link show              # promiscuous mode = sniffing

ps -eo pid,ppid,args | grep -E 'bash -i|/dev/tcp/|nc .* -e|mkfifo|socat .*exec'
# any hit on a desktop = investigate immediately
```

| Signal | Clean | Suspicious |
|---|---|---|
| bind address | `127.0.0.1` / `::1` | `0.0.0.0` / `*` on a port you do not serve |
| owning process | a program you recognise | `(null)` / no process / typo'd name |
| outbound queue | a host you contacted | an inbound-initiated or unknown remote |

### 10. Log & timestamp forensics

```bash
last -F | head -30
sudo lastb 2>/dev/null | head -30            # [root] failed logins
grep -E '\[ALPM\] (installed|upgraded)' /var/log/pacman.log | tail -40
journalctl -b -1 -p err
journalctl -u sshd -u systemd-logind --since "7 days ago" | tail -30
```

A **gap** in `pacman.log` around a date range (someone deleted lines) or `last` showing logins
that do not match your activity are the two tamper tells.

## Gotchas

| Apparent finding | Usually means | Real threat? |
|---|---|---|
| chkrootkit: NetworkManager is a "sniffer" | raw sockets are normal | **no** — suppress with `-s` |
| rkhunter: "unknown" binaries everywhere | no `--propupd` baseline | **no** — baseline on a clean state |
| `(deleted)` in `/proc/*/exe` during `-Syu` | binary replaced mid-upgrade | **no** — re-run when idle |
| taint ≠ 0 after NVIDIA/ZFS | legitimate out-of-tree module | **no** — but know the reason |
| `/var/spool/mail`, `/var/tmp` world-writable | Arch defaults | **no** |
| unhide: `/proc` count > `ps` count | — | **yes** — investigate now |
| `/sys/fs/bpf` non-empty / `hidden_*` maps | — | **yes** |
| `/etc/ld.so.preload` exists | — | **yes** |
| non-root-owned SUID binary | — | **yes** |
| altered files in `pacman -Qkk` under `/usr` | — | **yes** |

## Verification

There is no single "clean" command; verification is the set of expected outcomes:

```bash
cat /proc/sys/kernel/tainted                 # 0
ls /sys/fs/bpf/                              # empty
test -f /etc/ld.so.preload && echo BAD || echo clean
ls /proc | grep -E '^[0-9]+$' | wc -l        # equals `ps -e --no-headers | wc -l`
sudo rkhunter --check --sk                   # no warnings after a --propupd on clean state
sudo unhide proc                             # "Found HIDDEN PID: ..." absent
```

### If you actually find something — incident response

1. **Do not reboot.** Live memory holds the rootkit's working state and the proof of what it hooked.
2. **Do not trust the running system.** Every binary you run may be trojaned; prefer a read-only
   Arch ISO or another clean machine.
3. **Isolate.** Disconnect the network to cut the C2 channel.
4. **Preserve.** Copy `pacman.log`, `journalctl` output and `ss -tulpn` to external media first.
5. **Rotate credentials from a different device.** Anything in the running system's memory
   (`~/.ssh`, browser stores, keyrings) is compromised.
6. **The only guaranteed clean state is a reinstall** from verified media, restoring data from a
   re-scanned backup. A rootkit at kernel/EFI level cannot be reliably excised in place.
7. **Re-baseline** AIDE and `rkhunter --propupd` only on the confirmed-clean system.

## Honest limitations

Every rootkit scanner is **signature- or heuristic-based**. A bespoke kernel module with a novel
hiding technique beats rkhunter, chkrootkit *and* a manual audit — that is what zero-day means.
What actually bounds the risk, strongest first:

1. **Secure Boot + signed kernel + `module.sig_enforce=1` + `lockdown=`** — makes loading an
   unsigned LKM or tampering with the boot chain *structurally impossible*, not merely detectable
   ([[Boot and Secure Boot]], [[Kernel Hardening]]).
2. **An offline AIDE baseline** — an attacker cannot rewrite a database they cannot reach.
3. **Minimised AUR surface** — the realistic entry point on an Arch desktop.
4. **`kernel.unprivileged_bpf_disabled = 1`** — removes the eBPF rootkit class for non-root attackers.
5. Scanners — run them, but read a clean scan as *"no known compromise found"*, never *"clean"*.

## Related

- [[Monitoring, Integrity and Auditing]] — AIDE and auditd, the on-disk and event-log lenses
- [[Arch Lifecycle — Install, Maintain, Recover]] — AUR hygiene that prevents the likeliest vector
- [[Kernel Hardening]] — signatures, lockdown and BPF restrictions that bound the risk
- [[Arch Linux Security Hardening]] — where this sits in the whole picture
- [[Security Principles for Arch Linux]] — why prevention outranks detection

## Sources

- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — integrity, auditing and
  the baseline framing
- [rkhunter — ArchWiki](https://wiki.archlinux.org/title/Rkhunter) — install, `--propupd`,
  false-positive tuning
- [chkrootkit upstream](https://www.chkrootkit.org/) — test semantics and the false-positives file
- [Unhide — forensic process/port finder](https://sourceforge.net/projects/unhide-linux/) —
  `/proc` vs `ps` reconciliation
- [eBPF rootkit technique — June 2026 AUR supply-chain attack](https://github.com/A1RM4X/AUR-Malware-2026.06-Check)
  — the `hidden_*` pinned maps and IOC list
- [Linux kernel sysctl — tainted](https://docs.kernel.org/admin-guide/tainted-kernels.html) —
  the taint bitmask meanings

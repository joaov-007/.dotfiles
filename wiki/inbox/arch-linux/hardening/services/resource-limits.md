---
title: "Resource Limits and Fine-Tuning"
aliases:
  - Resource Limits
  - Resource Limits and Fine-Tuning
  - systemd resource control
  - cgroup limits
  - per-user limits
  - limits.conf
  - ulimit
description: >-
  How to bound what each user, service and program may consume on Arch: the PAM/RLIMIT layer
  (`limits.conf`, `ulimit`, `prlimit`), the systemd/cgroup-v2 layer (slices, `CPUWeight`,
  `CPUQuota`, `MemoryHigh`/`MemoryMax`, `TasksMax`, `IOWeight`), and the last-resort OOM
  handler (`systemd-oomd`) — plus the fine-tuning knobs (nice, ionice, journald and core-dump
  caps, disk quota) that sit alongside them.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - systemd
  - services
  - cgroups
  - resource-limits
  - oom
  - performance
type: reference
status: draft
created: 2026-10-14
updated: 2026-10-14
last_reviewed: 2026-10-14
review_after: 2027-04-14
language: en
audience: sysadmin
scope: >-
  Bounding resource consumption per user, per slice and per program: RLIMIT via PAM, cgroup-v2
  via systemd units, and OOM handling. Does not cover process confinement (see
  [[systemd and Application Sandboxing]]) or user authentication (see
  [[Access Control and Authentication]]).
platform:
  - arch-linux
  - systemd
keywords:
  - RLIMIT_NPROC
  - RLIMIT_NOFILE
  - pam_limits
  - limits.conf
  - ulimit
  - prlimit
  - cgroup v2
  - user slice
  - TasksMax
  - CPUWeight
  - CPUQuota
  - MemoryHigh
  - MemoryMax
  - MemorySwapMax
  - IOWeight
  - systemd-oomd
  - PSI
  - fork bomb
  - nice
  - ionice
  - journald rate limit
  - core dump
  - disk quota
related:
  - "[[systemd and Application Sandboxing]]"
  - "[[Access Control and Authentication]]"
  - "[[Kernel Hardening]]"
  - "[[Arch Linux Security Hardening]]"
  - "[[Monitoring, Integrity and Auditing]]"
  - "[[arch-system-audit]]"
  - "[[system-diagnostics-and-self-healing]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "User requested a guide on hardening via limits for user programs (how much each user may consume) and system fine-tuning, researched from ArchWiki, man pages and blogs"
ai-review: pending
---

# Resource Limits and Fine-Tuning

> [!summary] One-paragraph answer
> A machine falls over when one user or one program is allowed to consume everything. There are
> three layers of defence, and you want all three: **RLIMIT** (`limits.conf`, `ulimit`,
> `prlimit`) which caps a login session and counts per real UID; **cgroup v2** via systemd slices
> (`CPUWeight`/`CPUQuota`, `MemoryHigh`/`MemoryMax`, `TasksMax`, `IOWeight`) which is
> hierarchical, per-unit, covers memory, and is what you should prefer; and **`systemd-oomd`**,
> which kills the offending cgroup before the kernel stalls the whole box. Set *weights* so the
> machine stays fair under contention, and *caps* only where a hard ceiling is genuinely wanted.

## Context

"Hardening" is not only about who may do what — it is also about **how much anyone may use**.
A single build job, browser profile, or `cargo test -j$(nproc)` can otherwise pin every core,
fill every page of RAM, and wedge an interactive desktop before the kernel OOM killer reacts.

There are two questions, and they want different tools:

- **Per user, fairness** — "everyone gets their share, nobody starves". This is *weights*.
- **Per program, ceilings** — "this build must never eat more than 8 GiB". This is *caps*, and
  the same mechanisms applied to one unit.

Arch ships this stack turned on and mostly unlimited (systemd + cgroup v2 + `systemd-oomd`), so
the work is choosing the numbers, not installing anything. This note covers the limit layers, how
to read the current ceilings before changing them, and the smaller fine-tuning knobs (scheduling
priority, log and core-dump caps, disk quota) that belong with them.

## Details

### 1. The three layers, and when each applies

| Layer | Mechanism | Scope | Counts per | Covers memory? |
|---|---|---|---|---|
| RLIMIT | `limits.conf` → `pam_limits`; `ulimit`; `prlimit` | one PAM login session, inherited | real UID (system-wide) | only address-space (`as`/`rss`), coarsely |
| cgroup v2 | systemd slices, services, scopes | a unit and its whole subtree | unit / user / service | yes — `memory.high`/`memory.max`/`memory.swap.max` |
| OOM handling | `systemd-oomd` (PSI), `OOMPolicy=`, `OOMScoreAdjust=` | eligible cgroups | cgroup | kills the cgroup, not the `ulimit` victim |

Rules of thumb:

- **Prefer cgroups.** They are per-*user* (not per-UID-across-the-box), hierarchical, work for
  unprivileged users, and can bound memory (RLIMIT cannot, in practice).
- Use `limits.conf` for the handful of things cgroups do not expose as nicely — `nofile` for
  games, `core`, `nice`, `maxlogins` — and for anything you want a login session to carry.
- The OOM layer is the safety net, not the plan. It only fires when pressure already exists.

### 2. Read the current ceilings first

Never tune blind. systemd and the kernel already impose defaults, and they depend on the amount
of RAM (`kernel.threads-max`, `kernel.pid_max`).

```bash
# cgroup version — Arch is unified v2
stat -fc %T /sys/fs/cgroup                 # cgroup2fs

# what a user (all of uid 1000) is currently allowed
systemctl show user-1000.slice -p TasksMax -p MemoryHigh -p MemoryMax -p CPUWeight -p IOWeight

# what the manager gives any unit by default
grep -E 'DefaultLimitNOFILE|DefaultTasksMax|DefaultLimitNPROC' /etc/systemd/system.conf

# the two kernel-derived numbers that seed everything
sysctl kernel.pid_max kernel.threads-max
ulimit -u                                  # shell's RLIMIT_NPROC
```

Measured on this host (Arch, systemd 262, 7.5 GiB RAM) as a worked example:

| Value | Where it comes from |
|---|---|
| `TasksMax=20263` on `user-1000.slice` | `/usr/lib/systemd/system/user-.slice.d/10-defaults.conf` sets `33%` of the system task cap (= `kernel.threads-max`, 61406) |
| `DefaultTasksMax=15%` | other units get 15%; computed from `min(kernel.pid_max, kernel.threads-max, root pids.max)` |
| `RLIMIT_NPROC = 30703` | kernel gives PID 1 `kernel.threads-max / 2`; `DefaultLimitNPROC` is unset, so everything inherits it |
| `#DefaultLimitNOFILE=1024:524288` | shipped default (soft:hard) in `/etc/systemd/system.conf` |
| `Delegate=pids memory cpu`, `TasksMax=infinity` on `user@.service` | the per-user manager itself is trusted; the *slice* is what caps the user |
| `systemd-oomd` enabled and active | Arch enables it; `oomctl` shows the user's `app.slice` already monitored |

> [!tip] `TasksMax` is not `ulimit -u`
> `RLIMIT_NPROC` counts processes **per real UID for the whole system**, so a low value hits
> every session at once. `TasksMax` is the cgroup `pids` controller and counts **tasks (threads
> too) in one cgroup subtree**, so root, your user, and each service get independent budgets.
> That is why `TasksMax` — not `nproc` — is the fork-bomb defence on a systemd box.

### 3. Per-user limits with `limits.conf` (the RLIMIT layer)

`/etc/security/limits.conf` sets `setrlimit(2)` values for **PAM sessions**. Syntax:
`domain  type  item  value`, where `type` is `soft`/`hard`/`-`, `domain` is a user, `@group`, or
`*` (and `%group` on some PAM builds).

```ini
# /etc/security/limits.conf   (or better: a file in /etc/security/limits.d/99-local.conf)
# item          soft    hard     meaning
*               soft    core     0            # no core dumps by default...
*               hard    core     unlimited     # ...but allow `ulimit -c unlimited` when debugging
*               hard    nproc    4096          # fork-bomb ceiling per user (tune to your desktop)
*               soft    nofile   8192          # soft: raise a lot for games/JVM/databases
*               hard    nofile   524288
*               soft    priority 0             # default niceness
*               hard    nice     -19           # keep non-root away from max priority
root            hard    nproc    65536         # never starve root of processes
root            hard    nice     -20           # root may fix an unresponsive box
```

```bash
# session cap for the running shell / one process
ulimit -n                                  # current soft nofile
ulimit -Sn 4096 && ulimit -Hn 4096         # raise (only up to the hard limit, unprivileged)
prlimit --pid $$ --nofile=8192:8192        # change a running process's limit (root may raise hard)
prlimit --pid $$                            # read them all back
```

What you can limit here: `core`, `data`, `fsize`, `memlock`, `nofile`, `rss`, `stack`, `cpu`,
`nproc`, `as`, `locks`, `sigpending`, `msgqueue`, `nice`, `rtprio`, plus `maxlogins`,
`maxsyslogins`, `priority`, `chroot`.

> [!important] How the limits reach a session
> `pam_limits` is a **session** module. On Arch, `pam_limits` is pulled in by
> `/etc/pam.d/system-auth`, which is included by `system-login` (tty/login/display-manager
> sessions) *and* by `/usr/lib/pam.d/systemd-user`, the PAM file used by `user@.service`
> (`PAMName=systemd-user`). So on Arch, `limits.conf` also reaches the systemd **user manager**
> session — and every desktop process underneath it. That is *not* universal; distros that ship
> an empty `systemd-user` PAM file only apply `limits.conf` to login sessions, which is the
> source of most "my limits.conf does nothing" confusion.

### 4. The systemd-native way: slices and drop-ins

Everything a user runs lives under a slice named after their UID:

```text
-.slice
├── system.slice
│   └── NetworkManager.service
└── user.slice
    └── user-1000.slice                 ← per-user resource budget
        ├── session-2.scope             ← login/display-manager session
        └── user@1000.service           ← the user's own systemd manager
            ├── session.slice           ← compositor, pipewire… (latency-sensitive)
            └── app.slice               ← your apps
```

Set the budget on the **slice** to bound the whole user; set it on a **service** to bound one
program. `systemctl edit` writes a drop-in and never touches the packaged unit:

```bash
# every user, all users, same policy
sudo systemctl edit user-.slice         # → /etc/systemd/system/user-.slice.d/override.conf
# or one specific user
sudo systemctl edit user-1000.slice     # → /etc/systemd/system/user-1000.slice.d/override.conf
sudo systemctl daemon-reload
```

```ini
# /etc/systemd/system/user-.slice.d/60-limits.conf
[Slice]
# --- work-conserving shares: only matter under contention (100 = default) ---
CPUWeight=50            # half the weight of system.slice (100)
IOWeight=50
# --- hard ceilings: enforced even when the machine is idle ---
CPUQuota=400%           # at most four cores' worth of CPU time
MemoryHigh=6G           # soft wall: throttle + aggressive reclaim above this
MemoryMax=8G            # hard wall: in-cgroup OOM kill above this (last resort)
MemorySwapMax=2G        # stop one user from filling swap
TasksMax=4096           # fork-bomb ceiling for the entire user
```

The same keys belong in any `[Service]` — either in your own unit or a drop-in on a packaged
one:

```ini
# /etc/systemd/system/build.service.d/limits.conf
[Service]
CPUQuota=200%
MemoryHigh=4G
MemoryMax=6G
MemorySwapMax=0
TasksMax=512
IOWeight=20
```

Useful facts about the options:

- **`CPUWeight`/`IOWeight`** (1–10000, default 100) are *shares*: they do nothing while the
  resource is idle and decide the split when it is contended. Metadata:
  `cgroup cpu.weight`, `io.weight`.
- **`CPUQuota=`** is a hard cap as a percentage of *one* CPU (`200%` = two cores); it throttles
  even when the machine is idle. `CPUQuotaPeriodSec=` (default 100 ms) sets the measurement
  window.
- **`MemoryHigh=`** throttles and forces reclaim; **`MemoryMax=`** is the hard wall that triggers
  the cgroup OOM killer. The man page is explicit: use `MemoryHigh` as the main control,
  `MemoryMax` as the last line of defence.
- **`MemoryLow=`/`MemoryMin=`** protect a unit from reclaim — the right tool for the interactive
  session (see [[systemd and Application Sandboxing]] for the `session.slice` idea).
- **I/O caps** (`IOReadBandwidthMax=` etc.) are per **block device**, and you must name the
  originating device, not a partition: `/dev/nvme0n1`, via `lsblk -o NAME,MAJ:MIN`.
- **`AllowedCPUs=`** (cpuset) pins a unit to cores; for a *user* to set that on their own units,
  the manager needs `Delegate=cpuset` (Arch's `user@.service` delegates `pids memory cpu`).

Change a live value **without a reboot**, but mind the persistence flag:

```bash
systemctl set-property --runtime user-1000.slice MemoryMax=8G   # gone on reboot
systemctl set-property user-1000.slice MemoryMax=8G             # persists to /etc/systemd/system.control/
```

> [!note] `TasksMax` only bites new forks
> Lowering it does not kill processes that already exist; it stops the next `fork()`. `set-property`
> likewise applies the new ceiling to what is created afterwards.

### 5. Cap a single command (no unit file)

The quickest fine-tuning, and the honest way to test a limit before making it permanent:

```bash
# as a user, transient scope with caps — ideal for a heavy build or render
systemd-run --user --scope -p MemoryMax=2G -p CPUQuota=150% -p IOWeight=20 ./heavy-task

# run someone else's command inside a named slice, as another user
sudo systemd-run --uid=build --slice=ci.slice -p MemoryMax=4G make -j8

# a login shell already inside the limited slice
systemd-run --user --slice=limited.slice --shell
```

Containers do the same thing one level down and are a good template: `podman run --memory=2g
--pids-limit=256 --cpus=2 …` maps onto `MemoryMax=`, `TasksMax=`, `CPUQuota=` (see
[[quadlet]]).

### 6. Memory pressure: `MemoryHigh`/`MemoryMax` and `systemd-oomd`

On a desktop the failure mode is not a clean OOM kill — it is ten minutes of thrashing. PSI
(Pressure Stall Information) exposes how long tasks *stall* waiting for memory, and
`systemd-oomd` acts on it before the kernel has to:

```bash
cat /proc/pressure/memory        # system-wide stall time (avg10/avg60/avg300)
oomctl                          # what oomd is watching, and its current pressure
```

`systemd-oomd` ships in systemd, is enabled on Arch, and only acts where a unit opts in with
`ManagedOOMSwap=` / `ManagedOOMMemoryPressure=`. Its global defaults live in
`/etc/systemd/oomd.conf`:

```ini
[OOM]
SwapUsedLimit=90%                    # act when memory *and* swap are both above this
DefaultMemoryPressureLimit=60%       # "full" PSI stall fraction, 10 s window
DefaultMemoryPressureDurationSec=30s # how long pressure must persist
```

The Fedora-descended recipe tightens this for interactive sessions — a lower threshold means a
runaway tab is killed sooner, while your terminal stays responsive:

```ini
# /etc/systemd/system/user@.service.d/60-oomd.conf
[Service]
ManagedOOMMemoryPressure=kill
ManagedOOMMemoryPressureLimit=50%
ManagedOOMMemoryPressureDurationSec=20s
```

Around it:

- `ManagedOOMPreference=omit|avoid` on a **unit** makes it a less likely victim (databases,
  your editor); `none` is neutral.
- `OOMPolicy=` on a service controls what systemd does when the kernel kills one of its
  processes (`continue`, `stop`, `kill`).
- oomd kills a whole **leaf cgroup**, so keep parallel jobs in their own scope/slice; it will
  not cherry-pick a single process out of hundreds.
- swap must exist for the swap-based action to work; a plain `zram` swap is fine for
  pressure-based kills (see [[arch-encrypted-swap]]).

> [!caution] Alternatives and the swap prerequisite
> If the workload never touches disk swap, or you want a simpler C daemon, `earlyoom` and
> `nohang` are drop-in replacements for the same job. Do not run two OOM daemons at once.

### 7. Fine-tuning: priority, log volume and disk

These are the "turn the dials" knobs that complement limits. Most map to a `systemd.exec(5)`
directive, which is how you make them survive a reboot.

| Goal | Ad-hoc | Per-unit (systemd.exec) |
|---|---|---|
| Nice a heavy job | `nice -n 10 make`, `renice -n 5 -p PID` | `Nice=10` |
| Keep disk off the critical path | `ionice -c3 rsync …` | `IOSchedulingClass=idle` / `IOSchedulingPriority=` |
| Real-time-sensitive work | `chrt -f 10 …` | `CPUSchedulingPolicy=fifo`, `CPUSchedulingPriority=10` |
| Bias OOM victim selection | `choom -n 500 -p PID` | `OOMScoreAdjust=500` |
| Pin to cores | `taskset -c 0-3 …` | `AllowedCPUs=0-3` |

- **Automatic niceness** — `ananicy-cpp` adjusts `nice` per process from a ruleset; it is the
  modern replacement for the old `ananicy`. Do **not** run it together with GameMode — they
  fight over the same processes.
- **Cap the logs** — journald can itself be a disk hog. `SystemMaxUse=` / `MaxRetentionSec=` in
  `/etc/systemd/journald.conf`, and `RateLimitIntervalSec=`/`RateLimitBurst=` limit how much a
  single noisy service can write (a chatty crash loop is a denial-of-service of its own).
- **Cap core dumps** — `Storage=none` or `ProcessSizeMax=` in `/etc/systemd/coredump.conf` stops
  a crashing service from writing gigabytes to `/var`.
- **Bound `/tmp`** — a `tmpfs` with a `size=` mount option (or the systemd `tmp.mount`) caps how
  much RAM any user can pin through `/tmp` (see [[filesystem-and-physical]]).
- **Disk quota** — the other axis of "how much may each user consume". Ext4: mount with
  `usrquota,grpquota` and enable with `quotaon`. XFS: `xfs_quota`. Btrfs: subvolume qgroups
  (`btrfs quota enable <mount>` then `btrfs qgroup limit 50G /home/user`). There is no systemd
  equivalent — this is filesystem-level.

## Gotchas

> [!warning] `limits.conf` is not for system services
> PAM never sees `sshd.service`, `nginx.service`, or your own services. Set their limits in a
> systemd drop-in (`LimitNOFILE=`, `LimitNPROC=`, `LimitCORE=`, …) or with the resource-control
> keys above.

> [!danger] `MemoryMax=` too low kills the whole cgroup
> The hard wall triggers the *in-cgroup* OOM killer, which in a user slice can take down the
> entire session at once. Prefer `MemoryHigh=` for throttling and leave `MemoryMax=` as the
> backstop.

> [!caution] An `nproc` limit that is too low bricks logins
> New processes simply fail to spawn, including the ones you need to fix it. Keep a generous
> `root` line, and test the number in a throwaway session (`prlimit`) before committing it.

> [!warning] `nofile` too high breaks some tools
> A very high or `unlimited` `RLIMIT_NOFILE` trips `fakeroot` and a few build helpers. Set a
> large but finite hard value.

> [!caution] `set-property` persists by default
> Without `--runtime`, `systemctl set-property` writes to `/etc/systemd/system.control/`. Use the
> flag while experimenting, then codify the value in a real drop-in.

> [!note] Weights are not caps
> `CPUWeight=50` does *not* mean "half a CPU" — it means "half the shares when both want CPU".
> If you want a guarantee, use `CPUQuota=`.

## Verification

```bash
# per-user budget: does the number match what you set?
systemctl show user-1000.slice -p TasksMax -p MemoryMax -p MemoryHigh -p CPUWeight
cat /sys/fs/cgroup/user.slice/user-1000.slice/memory.max

# RLIMIT: what a session actually got (must be a fresh login/session)
systemctl show user@1000.service -p LimitNPROC -p LimitNOFILE
prlimit --pid $$ --nproc --nofile

# who is consuming what, live
systemd-cgtop --order=memory -m 2
systemd-cgls user.slice

# OOM: is oomd watching the right cgroup, and is there real pressure?
oomctl | head -20
cat /proc/pressure/memory
```

A safe live test of the `pids` cap (expect the fork loop to fail, the system to stay up):

```bash
systemd-run --user --scope -p TasksMax=50 bash -c \
  'for i in $(seq 1 500); do sleep 300 & done; wait' 2>&1 | tail -3
# → "Resource temporarily unavailable" / "fork: retry"
```

And a memory-cap test (expect the scope to be killed around the limit, not the desktop):

```bash
systemd-run --user --scope -p MemoryMax=256M \
  dd if=/dev/zero of=/dev/null bs=1M   # watch `oomctl` / journal for the kill
```

## Related

- [[systemd and Application Sandboxing]] — the same units, used to *confine* rather than *meter*
- [[Access Control and Authentication]] — `pam_limits` shares PAM with the auth stack; `sudo` policy
- [[Kernel Hardening]] — kernel side of OOM, PSI and `sysctl` tuning
- [[Monitoring, Integrity and Auditing]] — `auditd` and journals record limit hits and kills
- [[arch-system-audit]] — measuring a real host before you set the numbers
- [[Arch Linux Security Hardening]] — the map this note hangs off

## Sources

- [cgroups — ArchWiki](https://wiki.archlinux.org/title/Cgroups) — hierarchy, slices, user
  delegation, `set-property`, and the MatLab worked example
- [limits.conf — ArchWiki](https://wiki.archlinux.org/title/Limits.conf) — recommended `core`,
  `nice`, `nofile` and `nproc` values, and the fork-bomb rationale
- [Improving performance — ArchWiki](https://wiki.archlinux.org/title/Improving_performance) —
  I/O schedulers, `ionice`, `ananicy-cpp`, `scx`, and the userspace OOM daemon list
- [systemd.resource-control(5)](https://man.archlinux.org/man/systemd.resource-control.5.en) —
  authoritative semantics for every `CPU*`, `Memory*`, `Tasks*`, `IO*` and `ManagedOOM*` option
- [systemd.exec(5)](https://man.archlinux.org/man/systemd.exec.5.en) — `LimitXXX=`, `Nice=`,
  `IOScheduling*`, `CPUScheduling*`, `OOMScoreAdjust=`, `PAMName=`
- [systemd-system.conf(5)](https://man.archlinux.org/man/systemd-system.conf.5.en) —
  `DefaultTasksMax=15%`, `DefaultLimitNOFILE=1024:524288`, and the `DefaultLimit*` set
- [systemd-oomd.service(8)](https://man.archlinux.org/man/systemd-oomd.service.8.en) and
  [oomd.conf(5)](https://man.archlinux.org/man/oomd.conf.5.en) — PSI logic, `[OOM]` thresholds,
  the "lower the limit for `user@$UID.service`" recommendation
- [Resource Pressure Handling in systemd](https://systemd.io/PRESSURE/) — PSI, the pressure
  service protocol, and why services use it instead of a system-wide signal
- [systemd cgroups hacker guide](https://systemd.io/CGROUP_DELEGATION/) — two key design rules,
  single-writer, and `Delegate=`
- [Control Group v2 — Linux kernel](https://docs.kernel.org/admin-guide/cgroup-v2.html) and
  [PSI — Linux kernel](https://docs.kernel.org/accounting/psi.html) — `memory.high` vs
  `memory.max` vs `memory.swap.max`, `pids.max`, `cpu.weight`
- [pam_limits(8)](https://man.archlinux.org/man/pam_limits.8) / [limits.conf(5)](https://man.archlinux.org/man/limits.conf.5) —
  session module semantics, `uid=0` is affected too, the `set_all` warning
- [prlimit(1)](https://man.archlinux.org/man/prlimit.1) / [setrlimit(2)](https://man.archlinux.org/man/setrlimit.2) —
  the underlying RLIMIT interface and which limits unprivileged users may raise
- [Fedora — Enable systemd-oomd](https://fedoraproject.org/wiki/Changes/EnableSystemdOomd) —
  the reference `ManagedOOMMemoryPressureLimit=50%` policy for `user@.service`
- [cgroups v2 resource limits with systemd — FDC Servers](https://fdcservers.net/blog/cgroups-v2-resource-limits-with-systemd) —
  a practical write-up of quota-vs-weight and multi-tenant slice recipes
- [systemd, per-user CPU and/or memory limits — Server Fault](https://serverfault.com/questions/874274/systemd-per-user-cpu-and-or-memory-limits) —
  the `user-.slice.d` drop-in pattern, verified with `systemd-cgtop`
- [In defence of swap — Chris Down](https://chrisdown.name/2018/01/02/in-defence-of-swap.html) —
  why swap (or zram) is what lets an OOM daemon react in time; cited by `systemd-oomd(8)`

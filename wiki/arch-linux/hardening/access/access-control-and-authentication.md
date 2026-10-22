---
title: "Access Control and Authentication"
aliases:
  - Access Control and Authentication
  - apparmor
  - mandatory access control
  - PAM hardening
  - user and authentication hardening
  - sudo hardening
description: >-
  Confining what code can do (AppArmor, Landlock, application allow-listing) and proving who
  may log in (PAM faillock, password quality, no nullok, a locked root, hardened sudo). The
  zero-trust half of a hardening build: authenticate every actor, grant the least privilege,
  and deny by default.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - apparmor
  - mandatory-access-control
  - pam
  - authentication
  - sudo
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-14
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Mandatory access control (AppArmor, Landlock), the identity/authentication stack (PAM,
  password policy, sudo, doas) and process limits on a single Arch host. Does not cover SSH
  authentication — see [[SSH Hardening]].
platform:
  - arch-linux
  - systemd
keywords:
  - apparmor.service
  - aa-status
  - aa-enforce
  - aa-complain
  - aa-genprof
  - apparmor.d
  - landlock LSM
  - lsm= kernel parameter
  - /etc/security/pwquality.conf
  - pam_faillock
  - pam_pwquality
  - nullok
  - umask 077
  - passwd --lock root
  - /etc/sudoers.d
  - use_pty
  - log_input log_output
  - opendoas
  - limits.conf
related:
  - "[[Kernel Hardening]]"
  - "[[Resource Limits and Fine-Tuning]]"
  - "[[SSH Hardening]]"
  - "[[Monitoring, Integrity and Auditing]]"
  - "[[Security Principles for Arch Linux]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Access Control and Authentication

> [!summary] One-paragraph answer
> Two questions, two tool sets. **Discretionary access control** (users, sudo, file modes) only
> says which *user* may do something; **mandatory access control** (AppArmor, Landlock) confines
> *what a program may do* even when it is exploited. On Arch, `apparmor` is the supported MAC
> stack. Authentication is the other half: `pam_faillock` to stop brute force, `pam_pwquality` for
> real passwords, `nullok` removed, root locked, and `sudo` with `use_pty` and full logging. This
> is the OS-level expression of "never trust, always verify".

## Context

Open this when you want to bound the damage an exploited application can do, or when you are
tightening login and privilege-escalation on a machine that has more than one way in (a second
account, a login manager, or SSH). It assumes you already have a non-root user in `wheel` and
use `sudo` rather than `su`.

## Details

### 1. Mandatory access control — AppArmor

AppArmor confines programs by path, which makes it far simpler on Arch than SELinux (possible,
but requires rebuilding core packages and is not a supported default).

```bash
sudo pacman -S apparmor apparmor-utils

# enable at boot (drop-in, so a kernel update cannot silently drop it)
echo 'apparmor=1 security=apparmor lsm=landlock,lockdown,yama,integrity,apparmor,bpf' \
  | sudo tee /etc/cmdline.d/apparmor.conf

sudo systemctl enable --now apparmor.service
aa-enabled        # Yes
aa-status         # loaded profiles + enforce/complain counts
```

Profile modes:

| Mode | Effect |
|---|---|
| `enforce` | violations blocked and logged |
| `complain` | violations logged, **not** blocked (use while testing) |
| `unconfined` | no restrictions |

```bash
# roll a profile out safely, then enforce it
sudo aa-complain /etc/apparmor.d/usr.bin.example
sudo aa-logprof                       # turn logged denials into rules
sudo aa-enforce /etc/apparmor.d/usr.bin.example
```

> [!note] The `lsm=` order matters
> `apparmor` must be in the chain and, on most setups, before `bpf`. Verify the running order:
> `cat /sys/kernel/security/lsm`. A wrong order means profiles never attach even though the
> service "starts".

> [!tip] Generate profiles for your own programmes
> `sudo aa-genprof /usr/bin/tool`, exercise the tool, then `sudo aa-logprof` and enforce. This is
> how you confine something with no upstream profile.

### 2. Landlock and allow-listing

Landlock is an unprivileged LSM (kernel 5.13+) used by sandboxes such as Flatpak's bubblewrap; it
needs no userspace configuration beyond being present in `lsm=`. The Arch analogue of RHEL's
application allow-listing (`fapolicyd`) is a combination of **AppArmor profiles** plus
**`noexec`** on user-writable mounts (see [[Filesystem and Physical Security]]) — there is no
in-tree `fapolicyd` package, so "allow-list" here means confining what an allowed binary may do.

### 3. Password quality — `pam_pwquality`

```bash
sudo pacman -S libpwquality
```

```ini
# /etc/security/pwquality.conf
minlen = 16
dcredit = -1
ucredit = -1
ocredit = -1
lcredit = -1
maxrepeat = 3
maxclassrepeat = 4
dictcheck = 1
usercheck = 1
enforcing = 1
```

### 4. Brute-force lockout — `pam_faillock`

`pam_faillock` is the modern replacement for `pam_tally2` and ships default limits on Arch.

```ini
# /etc/pam.d/system-auth (add the faillock lines around pam_unix)
auth      required  pam_faillock.so preauth   deny=3 fail_interval=900 unlock_time=600 even_deny_root
auth      required  pam_unix.so
auth      required  pam_faillock.so authfail  deny=3 fail_interval=900 unlock_time=600 even_deny_root
account   required  pam_faillock.so
```

```bash
# inspect and clear lockouts
faillock --user joaov
sudo faillock --user joaov --reset
```

### 5. Remove `nullok` and lock root

An empty password is an authentication bypass; `nullok` tells PAM to accept one.

```bash
grep -r nullok /etc/pam.d/        # remove the option from every hit
sudo passwd --lock root           # root exists, but cannot log in with a password
awk -F: '($2 == "") {print $1}' /etc/shadow   # must print nothing
```

### 6. Least privilege — sudo and umask

```ini
# /etc/sudoers.d/hardening  (validate with visudo)
Defaults env_reset
Defaults mail_badpass
Defaults secure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Defaults use_pty
Defaults logfile="/var/log/sudo.log"
Defaults log_input, log_output
Defaults iolog_dir="/var/log/sudo-io/%{user}"
Defaults passwd_tries=3
Defaults timestamp_timeout=5
%wheel    ALL=(ALL:ALL) ALL
```

```bash
# restrictive default file creation for new logins
echo 'umask 077' | sudo tee /etc/profile.d/umask.sh

# optional tighter process limits
# /etc/security/limits.conf
# *       hard  nproc  100
# *       hard  maxlogins 3
```

> [!tip] Capability-scoped sudo beats blanket `ALL`
> `%wheel ALL=(ALL:ALL) ALL` is convenient but unlimited. Where a job only needs one command,
> grant only that: `joaov ALL=(root) /usr/bin/pacman`. `opendoas` is a smaller, more auditable
> alternative if you prefer a config file to a `sudoers` grammar.

### 7. Non-human identities

The zero-trust extension: services are actors too. A daemon should run as its own unprivileged
user, hold the fewest capabilities, and be confined — not run as root with open access. That work
lives in [[systemd and Application Sandboxing]] (drop-ins, `Protect*`, `SystemCallFilter`).

## Gotchas

> [!warning] AppArmor v4 login breakage
> If `/etc/shadow` or `/etc/gshadow` have wrong permissions, AppArmor v4 can block logins. Boot
> with `apparmor=0`, then `chmod 600 /etc/shadow /etc/gshadow`.

> [!caution] `aa-enforce` on everything at once
> Enforcing the full profile set in one step breaks desktops in ways that are hard to trace
> (Samba, some compositors). Move profiles to `complain`, watch `journalctl -k | grep -i denied`,
> then enforce — or use the curated `apparmor.d` AUR set and review before enforcing.

> [!danger] Locking root without a working sudo first
> `passwd --lock root` is correct only after `sudo` is proven working for a real user. Otherwise
> you have locked yourself out of privilege escalation entirely. Keep a root shell open until you
> have verified `sudo -v` from another session.

> [!warning] `pam_faillock` and `even_deny_root`
> `even_deny_root` locks root too. That is desirable, but combine it with a tested recovery path
> (single-user boot) so a lockout is not a brick.

## Verification

```bash
aa-status | head -5                       # apparmor active, profiles loaded
faillock --user joaov                     # shows policy; empty when not locked
sudo -l                                   # expected sudo rights
passwd -S root | awk '{print $2}'         # L = locked
awk -F: '($2 == "") {print $1}' /etc/shadow   # empty output
```

## Related

- [[Kernel Hardening]] — `ptrace_scope`, unprivileged BPF, and the runtime bounds MAC relies on
- [[SSH Hardening]] — key-only access and FIDO2, the remote form of the same authentication
- [[Monitoring, Integrity and Auditing]] — `auditd` watches the files this note protects
- [[Security Principles for Arch Linux]] — least privilege and "verify every actor"

## Sources

- [AppArmor — ArchWiki](https://wiki.archlinux.org/title/AppArmor) — install, `lsm=` ordering,
  complain/enforce workflow, the v4 shadow caveat
- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — PAM, restrictive umask,
  SUID and user-account recommendations
- [pam_faillock(8)](https://man.archlinux.org/man/pam_faillock.8) — deny/fail_interval/unlock_time
  semantics
- [pam_pwquality(8)](https://man.archlinux.org/man/pam_pwquality.8) — the options in
  `/etc/security/pwquality.conf`
- [sudoers(5)](https://man.archlinux.org/man/sudoers.5) — `use_pty`, `log_input`/`log_output`
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) —
  "never trust, always verify"; least privilege; identity for human and non-human actors

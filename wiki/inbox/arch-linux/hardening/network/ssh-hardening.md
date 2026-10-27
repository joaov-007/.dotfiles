---
title: "SSH Hardening"
aliases:
  - SSH Hardening
  - sshd_config
  - OpenSSH hardening
  - FIDO2 ssh key
description: >-
  Making an OpenSSH server something you can reason about: key-only authentication, root login
  refused, forwarding and agents off, strong algorithms only, and FIDO2-backed keys for the
  human side — plus why the port number is not one of the controls.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - ssh
  - authentication
  - networking
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Server and client SSH configuration on Arch: `/etc/ssh/sshd_config`, key management, FIDO2
  keys. Does not cover the firewall that limits exposure — see [[Firewall Configuration]].
platform:
  - arch-linux
  - openssh
keywords:
  - PermitRootLogin no
  - PasswordAuthentication no
  - KbdInteractiveAuthentication
  - AllowUsers
  - MaxAuthTries
  - LoginGraceTime
  - Ciphers chacha20-poly1305
  - MACs hmac-sha2-512-etm
  - KexAlgorithms curve25519-sha256
  - sshd -t
  - sshd -T
  - ssh-keygen ed25519
  - ed25519-sk
  - FIDO2
  - AllowTcpForwarding no
  - ClientAliveInterval
related:
  - "[[Firewall Configuration]]"
  - "[[Access Control and Authentication]]"
  - "[[Network and Browser Privacy]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# SSH Hardening

> [!summary] One-paragraph answer
> An OpenSSH server should accept **keys, not passwords**, refuse root, run as few users as
> possible, and offer only modern algorithms. Everything else — the port number, banners, even
> `MaxAuthTries` — is secondary. The highest-value modern step is a **hardware-backed key**
> (`ed25519-sk`, FIDO2), which makes a stolen key file useless without the physical token.

## Context

Open this when `sshd` is enabled. On a desktop that never accepts SSH, the strongest move is to
leave `sshd` disabled entirely (the firewall in [[Firewall Configuration]] is then only a
backstop). When you do run it, the checklist below is what to change from the stock file.

## Details

### 1. The server configuration

Edit `/etc/ssh/sshd_config` (or drop a file in `/etc/ssh/sshd_config.d/`):

```ini
# Authentication: keys only
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitEmptyPasswords no
PubkeyAuthentication yes

# Who may connect at all
AllowUsers joaov

# Do not hand out access you did not intend
AllowTcpForwarding no
X11Forwarding no
AllowAgentForwarding no
HostbasedAuthentication no
IgnoreRhosts yes

# Timeouts and limits
LoginGraceTime 30
MaxAuthTries 3
MaxSessions 3
ClientAliveInterval 300
ClientAliveCountMax 2

# Modern algorithms only
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,sntrup761x25519-sha512@openssh.com

UsePAM yes
LogLevel VERBOSE
```

```bash
sudo sshd -t          # syntax check — must be silent
sudo sshd -T | grep -E 'passwordauthentication|permitrootlogin'   # effective values
sudo systemctl reload sshd
```

> [!important] `sshd -t` before every reload
> A typo in `sshd_config` means the next restart leaves you with no SSH and, on a remote box, no
> way in. Always `sshd -t`, and never reload while relying on the session you are in.

### 2. Keys — generate strong, prefer hardware

```bash
# software key, encrypted with a passphrase and many KDF rounds
ssh-keygen -t ed25519 -a 100 -C "joaov@host"

# hardware-backed key: the private key cannot leave the token
ssh-keygen -t ed25519-sk -O resident -O verify-required
```

> [!tip] `ssh-agent` with confirmation
> `ssh-add -c` asks before each use of a key, so a compromised agent cannot silently authenticate.
> Combined with a FIDO2 key's `verify-required` (a PIN/touch), this is the closest OpenSSH gets to
> the MFA the zero-trust model asks for.

### 3. Client hardening

```sshconfig
# ~/.ssh/config
Host *
    HashKnownHosts yes
    VisualHostKey yes
    StrictHostKeyChecking ask
    ForwardAgent no
    ForwardX11 no
    IdentitiesOnly yes
```

> [!note] `StrictHostKeyChecking ask` vs `yes`
> `ask` keeps the classic trust-on-first-use prompt; `yes` refuses unknown hosts outright.
> `accept-new` is a middle ground but silently trusts the first connection — avoid it for hosts
> you care about.

## Gotchas

> [!danger] Locking yourself out
> Set up and **test** key login from a second session before setting `PasswordAuthentication no`.
> Keep that session open during the change. On a remote host, know how to reach a console or
> rescue environment first.

> [!warning] `AllowUsers` and typo'd usernames
> A misspelled `AllowUsers` line denies everyone. Verify with `sudo sshd -T` and a fresh login.

> [!caution] Aging algorithm lists
> Hard-coding `KexAlgorithms`/`Ciphers` is good until a client cannot negotiate. Keep the list to
> what the SSH version in use supports; prefer the `*+`/`-` modifier syntax (e.g.
> `Ciphers -aes128-ctr`) over a frozen absolute list when you can.

## Verification

```bash
sudo sshd -T | grep -Ei 'passwordauth|permitroot|allowusers|maxauthtries'
# expect: passwordauthentication no · permitrootlogin no · allowusers joaov
sudo systemctl status sshd --no-pager
ssh -o PreferredAuthentications=password -o PubkeyAuthentication=no joaov@localhost
# expect: Permission denied (publickey) — password auth is off
```

## Related

- [[Firewall Configuration]] — rate-limit and restrict which hosts may even reach `sshd`
- [[Access Control and Authentication]] — PAM and sudo, the local half of the same identity story
- [[Network and Browser Privacy]] — the transport underneath, and MAC randomization

## Sources

- [OpenSSH — ArchWiki](https://wiki.archlinux.org/title/OpenSSH) — `sshd_config.d`, `sshd -T`,
  key types including FIDO2, and the "change the port is not security" note
- [sshd_config(5)](https://man.archlinux.org/man/sshd_config.5) — every directive above
- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — SSH among the baseline
  services to disable or harden

---
title: "Firewall Configuration"
aliases:
  - Firewall Configuration
  - nftables
  - ufw
  - firewall
description: >-
  Default-deny in the kernel with nftables (or the ufw front-end): how the input, forward and
  output chains differ, why the forward chain matters even on a desktop, and why an output
  drop policy breaks mDNS, Syncthing and local model servers — plus rate limiting as a cheap
  brute-force brake.
tags:
  - arch-linux
  - linux
  - security
  - hardening
  - firewall
  - nftables
  - ufw
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
  Host firewall on a single Arch machine: nftables ruleset and the ufw front-end. Does not cover
  exposing a service to the internet (see [[SSH Hardening]]) or DNS/network privacy
  ([[Network and Browser Privacy]]).
platform:
  - arch-linux
keywords:
  - /etc/nftables.conf
  - nft list ruleset
  - nft -c -f
  - policy drop
  - ct state established
  - inet filter table
  - ufw default deny incoming
  - ufw status verbose
  - rate limit
  - sshguard
  - fail2ban
  - output chain
related:
  - "[[SSH Hardening]]"
  - "[[Network and Browser Privacy]]"
  - "[[Security Principles for Arch Linux]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Firewall Configuration

> [!summary] One-paragraph answer
> The firewall is the cheapest structural control on the machine: deny inbound traffic nobody
> asked for. nftables is the modern kernel interface; ufw is a simple front-end over it. A
> desktop wants **default-drop input**, **default-drop forward**, and **output left open** —
> an output policy of `drop` sounds like zero trust but breaks mDNS, Syncthing, browsers and
> local model servers. Rate-limit the few exposed ports and stop there.

## Context

Open this when the machine is reachable from a network — a laptop on untrusted Wi-Fi, or a box
with any listening service. The decision is which of the three chains you tighten and how far.
Most desktops need input and forward only.

| Chain | What it governs | Desktop default |
|---|---|---|
| `input` | traffic to a service on this host | **drop**, allow what you serve |
| `forward` | traffic routed *through* this host | **drop** (you are not a router) |
| `output` | traffic this host originates | **accept** — see the warning below |

## Details

### 1. nftables — the ruleset

```bash
sudo pacman -S nftables
```

```nft
# /etc/nftables.conf
#!/usr/sbin/nft -f
flush ruleset

table inet filter {
    chain input {
        type filter hook input priority filter; policy drop;
        ct state invalid drop
        iif "lo" accept
        ct state established,related accept

        # rate-limit anything exposed (SSH, etc.)
        tcp dport 22 ct state new limit rate 15/minute accept

        ip protocol icmp icmp type { echo-request, destination-unreachable, time-exceeded } accept
        ip6 nexthdr icmpv6 icmpv6 type { echo-request, destination-unreachable,
            packet-too-big, time-exceeded, nd-neighbor-solicit, nd-neighbor-advert } accept

        log prefix "nft-input-drop: " counter
    }

    chain forward {
        type filter hook forward priority filter; policy drop;
        ct state established,related accept
        ct state invalid drop
    }

    chain output {
        type filter hook output priority filter; policy accept;
    }
}
```

```bash
nft -c -f /etc/nftables.conf        # syntax check before loading
sudo systemctl enable --now nftables.service
sudo nft list ruleset | head
```

> [!danger] The `forward` chain is not optional on a laptop
> A laptop joins networks where it may be asked to route. Leaving `forward` at `accept` turns the
> machine into a transit hop for anyone on the link. `policy drop` on forward costs nothing.

### 2. ufw — a front-end over nftables

If you prefer a simpler interface, `ufw` (Uncomplicated Firewall) writes nftables rules for you.
Do not run both — pick one and let the other stay disabled.

```bash
sudo pacman -S ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'ssh'
sudo ufw enable
sudo ufw status verbose
```

### 3. Rate limiting and lockout tools

A rate limit on the exposed port is cheap protection against a scanner or a slow brute force:

```nft
tcp dport 22 ct state new limit rate 15/minute accept
```

For more than the ruleset can express, add a log-driven blocker (one only):

```bash
sudo pacman -S sshguard && sudo systemctl enable --now sshguard.service
# or
sudo pacman -S fail2ban && sudo systemctl enable --now fail2ban.service
```

> [!note] Changing the SSH port is not a security control
> Moving `sshd` to a non-default port only reduces log noise; the ArchWiki says so explicitly.
> If you move it, remember to open the new port in the ruleset **before** you close 22.

### 4. Output-chain hardening (usually wrong on a desktop)

An output `policy drop` with an explicit allow-list looks maximally zero-trust. In practice it
breaks name resolution done outside the resolver, mDNS discovery, Syncthing, ollama, and any
browser connecting to a port you did not predict. If you want it anyway, monitor first:

```nft
chain output {
    type filter hook output priority filter; policy drop;
    oif "lo" accept
    ct state established,related accept
    udp dport 53 accept
    tcp dport { 80, 443 } accept
    udp dport 123 accept
    log prefix "nft-output-drop: " counter
}
```

> [!warning] Test an output drop from the console, not over SSH
> You will lock yourself out of a remote session if you load a wrong output policy. Keep a
> physical console open; flush with `sudo nft flush ruleset` if it goes wrong.

## Gotchas

> [!danger] Lockout recovery
> If a ruleset cuts your session, from a local console run `sudo nft flush ruleset` (immediate) or
> `sudo systemctl stop nftables` (for ufw: `sudo ufw disable`). Never load an unverified ruleset
> remotely without an out-of-band way back in.

> [!caution] Two firewalls, one kernel
> `nftables.service` and `ufw.service` both program the same nftables backend. Running both
> produces rule ordering you did not intend. Pick one.

> [!warning] `ct state established` before the drop
> Rules are evaluated in order. If you drop before accepting `established,related`, you kill
> your own replies. The order in the ruleset above matters.

## Verification

```bash
# policy is drop, and only expected ports are open
sudo nft list chain inet filter input
sudo ufw status verbose            # Default: deny (incoming), allow (outgoing)

# nothing unexpected is listening
ss -tulpn

# a scan from another host shows only the intended ports
```

## Related

- [[SSH Hardening]] — the service the rate limit protects
- [[Network and Browser Privacy]] — encrypted DNS and MAC randomization on the same stack
- [[Security Principles for Arch Linux]] — why output-drop is a trade-off, not a default

## Sources

- [nftables — ArchWiki](https://wiki.archlinux.org/title/Nftables) — ruleset syntax, service,
  `nft -c` check
- [Simple stateful firewall — ArchWiki](https://wiki.archlinux.org/title/Simple_stateful_firewall)
  — chain ordering and connection tracking
- [ufw — ArchWiki](https://wiki.archlinux.org/title/Uncomplicated_Firewall) — default policies
  and enabling
- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — firewall as a baseline
  control and the "change the port is not security" note
- [NIST SP 800-207 — Zero Trust Architecture](https://csrc.nist.gov/pubs/sp/800/207/final) —
  "assume networks and network traffic are compromised by default"

---
title: "Network and Browser Privacy"
aliases:
  - Network and Browser Privacy
  - network hardening
  - browser hardening
  - MAC address randomization
  - encrypted DNS
description: >-
  The privacy half of network hardening on a desktop: randomizing the MAC so a network cannot
  track the machine between visits, encrypting DNS so the resolver cannot sell your queries,
  turning off the services that broadcast your presence, and a Firefox `user.js` that reduces
  telemetry, fingerprinting and linkability.
tags:
  - arch-linux
  - linux
  - security
  - privacy
  - networking
  - dns
  - hardening
  - mac-address-randomization
type: reference
status: draft
created: 2026-10-10
updated: 2026-10-10
last_reviewed: 2026-10-10
review_after: 2027-04-10
language: en
audience: sysadmin
scope: >-
  Client-side network and browser privacy on a single host: MAC randomization, encrypted DNS
  hand-off, disabling chatty services, and Firefox preferences. Does not document the DNS
  resolver itself — that is [[arch-dnscrypt-proxy]].
platform:
  - arch-linux
  - networkmanager
keywords:
  - wifi.cloned-mac-address
  - ethernet.cloned-mac-address
  - wifi.scan-rand-mac-address
  - NetworkManager conf.d
  - dnscrypt-proxy
  - DNS over HTTPS
  - DNS over TLS
  - unbound
  - avahi-daemon
  - cups
  - bluetooth
  - toolkit.telemetry.enabled
  - privacy.resistFingerprinting
  - dom.security.https_only_mode
  - network.cookie.cookieBehavior
related:
  - "[[Firewall Configuration]]"
  - "[[arch-dnscrypt-proxy]]"
  - "[[SSH Hardening]]"
  - "[[Security Principles for Arch Linux]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to split the Arch Linux hardening guide into focused notes"
ai-review: pending
---

# Network and Browser Privacy

> [!summary] One-paragraph answer
> A hardened network stack on a desktop is mostly about **not leaking**: a randomized MAC so
> Wi-Fi hotspots cannot follow the machine, encrypted DNS so the resolver cannot read every
> hostname, and no mDNS/CUPS/Bluetooth chatter advertising what the machine is. The browser is
> the largest untrusted-code surface on the machine; a small `user.js` cuts telemetry, forces
> HTTPS and raises fingerprinting resistance. This is "assume the network is hostile" made local.

## Context

Open this on a laptop that joins public or shared networks, or when you want the browser to leak
less. The DNS piece assumes you have already chosen a resolver; this note only wires the client
to it and points at [[arch-dnscrypt-proxy]] for the resolver's own configuration.

## Details

### 1. MAC address randomization

A fixed MAC is a persistent identifier across every network you join. NetworkManager can
randomize it per connection and while scanning:

```ini
# /etc/NetworkManager/conf.d/mac-randomization.conf
[device]
wifi.scan-rand-mac-address=yes

[connection]
wifi.cloned-mac-address=random
ethernet.cloned-mac-address=random
```

```bash
sudo systemctl restart NetworkManager
ip link show          # the MAC should differ from the hardware address
```

> [!caution] Captive portals and MAC whitelists
> Some hotel/enterprise networks bind a session to the MAC. If a portal loops after you
> authenticate, set `cloned-mac-address=stable` for that connection instead of `random`.

### 2. Encrypted DNS

Plain DNS is readable by every hop and by the resolver. Point the client at an encrypted resolver:

```bash
# the vault's DNS note covers the full setup
# pacman -S dnscrypt-proxy  →  see [[arch-dnscrypt-proxy]]
```

Wiring options, strongest to simplest:

| Method | Notes |
|---|---|
| `dnscrypt-proxy` on `127.0.0.1:53` | DNS-over-HTTPS + anonymized relays; see [[arch-dnscrypt-proxy]] |
| `systemd-resolved` with DoT | `DNSOverTLS=yes`, then point `resolved` at the stub |
| `unbound` recursive | no upstream resolver at all; needs maintenance |

### 3. Turn off services that announce the machine

Every listening service is both attack surface and a presence beacon:

```bash
ss -tulpn | sort -k4
sudo systemctl disable --now avahi-daemon.service     # mDNS/LLMNR on 0.0.0.0:5353
sudo systemctl disable --now cups.service             # printing, if you never print
sudo systemctl disable --now bluetooth.service        # if you have no BT peripherals
```

> [!note] Disable only what you do not use
> Avahi is genuinely useful if you `ssh host.local` or use network printers; CUPS if you print;
> Bluetooth if you use a BT mouse. Removing a service you rely on just gets it re-enabled.

### 4. Browser hardening — Firefox `user.js`

Place `user.js` in the profile directory (`about:support` → Profile Directory) and restart:

```javascript
// Telemetry off
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("browser.ping-centre.telemetry", false);

// Leak reduction
user_pref("media.peerconnection.enabled", false);      // WebRTC IP leak
user_pref("network.cookie.cookieBehavior", 5);         // total cookie protection / partition
user_pref("privacy.resistFingerprinting", true);       // raises fingerprinting cost

// Transport
user_pref("dom.security.https_only_mode", true);       // HTTPS-only, no fallback
```

> [!warning] `resistFingerprinting` breaks sites
> It changes timezone, canvas, font and window metrics. Some web apps break or look wrong. Keep
> a normal profile if you rely on one that does.

> [!tip] Telemetry also lives at the OS level
> Firefox is the biggest leak, but check the desktop environment's own telemetry/analytics
> settings and `systemd-timers` that phone home. `ss -tnp` shows what is connecting out right now.

## Gotchas

> [!caution] DNS leaks through other paths
> Encrypted DNS only helps if *all* name resolution uses it. Applications with hard-coded
> resolvers (some VPNs, some browsers' own DoH) bypass `127.0.0.1`. Verify with
> `resolvectl status` or by watching `ss -tunp` for port 53 leaving the machine.

> [!warning] MAC randomization vs router configuration
> Static DHCP reservations keyed to the old MAC stop working. That is the feature, not a bug —
> but plan for it.

> [!caution] `user.js` is overwritten by the profile, not the app
> On Firefox updates the profile is kept; on profile reset it is not. Keep a copy of your
> `user.js` in your dotfiles repository.

## Verification

```bash
# MAC is not the hardware address
ip link | grep -i permaddr     # and compare with the current link/ether
ip -br link

# resolution goes through the encrypted resolver
resolvectl status 2>/dev/null | head
ss -tunp | grep ':53'          # expect 127.0.0.1:53, not an external resolver

# chatty services are gone
ss -tulpn | grep -E ':5353|:631'
```

## Related

- [[arch-dnscrypt-proxy]] — the resolver this note points the client at
- [[Firewall Configuration]] — what may connect in; this note is what may leak out
- [[SSH Hardening]] — the transport that rides on this stack
- [[Security Principles for Arch Linux]] — "assume the network is compromised"

## Sources

- [NetworkManager — ArchWiki](https://wiki.archlinux.org/title/NetworkManager) — `cloned-mac-address`
  and MAC randomization settings
- [DNSCrypt — ArchWiki](https://wiki.archlinux.org/title/Dnscrypt-proxy) — encrypted-DNS client
  setup
- [Firefox — ArchWiki](https://wiki.archlinux.org/title/Firefox) — profile layout and
  privacy preferences
- [Security — ArchWiki](https://wiki.archlinux.org/title/Security) — minimising running services
- [PrivacyBadger/arkenfox `user.js`](https://github.com/arkenfox/user.js) — the widely-maintained
  source many `user.js` sets derive from (read before copying)

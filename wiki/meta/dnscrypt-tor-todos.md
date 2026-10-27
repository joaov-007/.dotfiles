---
title: "dnscrypt-proxy over Tor — Todo Tracker"
aliases:
  - dnscrypt tor todos
  - dnscrypt tor tracker
description: >-
  Working tracker for the dnscrypt-proxy-over-Tor workstream on host bacon: the live-state
  findings, the decisions taken, the deploy steps still outstanding, and the rollback notes.
tags:
  - meta
  - dnscrypt
  - tor
  - containers
  - podman
  - networking
  - privacy
type: runbook
status: needs-action
confidence: high
created: 2026-10-14
updated: 2026-10-14
last_reviewed: 2026-10-14
review_after: 2027-04-14
language: en
audience: maintainer
scope: Session tracker for the dnscrypt-proxy + Tor work (host + containers)
related:
  - "[[dnscrypt-proxy-tor]]"
  - "[[arch-dnscrypt-proxy]]"
  - "[[dnscrypt-proxy-podman]]"
  - "[[searxng-tor]]"
cssclasses:
  - reference
keywords:
  - dnscrypt-proxy
  - tor
  - podman
  - dns
platform:
  - Arch Linux
  - Podman
---

# dnscrypt-proxy over Tor — Todo Tracker

Started: 2026-10-14 · Host: `bacon` (Arch, Podman 6.1.3, cgroup v2)

The deliverable note is [[dnscrypt-proxy-tor]]. This file tracks the state of the work so a
future session does not have to re-read the host.

## Artifacts

- Deliverable: `containers/dnscrypt-proxy-tor.md` — runbook, status `draft`, ~900 lines.
- Tracker: this file. Linked from [[Home]] (table, topic line, and needs-attention callout).
- Cross-links patched into [[arch-dnscrypt-proxy]], [[dnscrypt-proxy-podman]] and
  [[searxng-tor]] (all reciprocal).

## Live-state findings (verified 2026-10-14, read-only)

- [x] `dnscrypt-proxy.service` **active + enabled** on `127.0.0.1:53` + `[::1]:53` (tcp/udp/mptcp); socket unit **disabled**.
- [x] Drop-in `dnscrypt-proxy.service.d/override.conf` present (ProtectProc/ProtectClock/RestrictSUIDSGID/RestrictAddressFamilies/SocketBind).
- [x] **LEAK:** `/etc/resolv.conf` = `nameserver 187.33.208.9` + `8.8.8.8` — host is **not** using the local proxy.
- [x] **NOT TOR:** `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` has `force_tcp = false` and no `proxy =`.
- [x] `require_dnssec/require_nolog/require_nofilter = true`, `odoh_servers = true`, `ipv6_servers = true`.
- [x] Local blocklist wired: `blocked_names_file = /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.txt` (8.9 MB).
- [x] Blocklist **stale** (early Oct) and **no refresh timer** under `~/.config/systemd/user/`.
- [x] `enable_hot_reload` unset → default false.
- [x] `tor.service` **inactive**; `searxng-tor` container holds `127.0.0.1:9050` + `8118`.
- [x] Networks: `podman` 10.88.0.0/16, `systemd-searxng` 10.247.1.0/24. Chosen new: 10.250.53.0/24.
- [x] `net.ipv4.ip_unprivileged_port_start = 1024`; `Linger=yes`.
- [x] No official dnscrypt-proxy client image; `klutchell/dnscrypt-proxy` = SHA tags only; `jauderho/dnscrypt-proxy:2.1.18` has semver.

## Decisions

- [x] Tor egress placement: **A** host `tor.service` (SocksPort **9052**) for the native daemon; **B** dedicated internal Tor container for the container network. Not the searxng sidecar (coupling).
- [x] Isolated circuit via fake SOCKS user/pass `dnscrypt:dnscrypt`; `force_tcp = true`; `http3 = false`.
- [x] Ad-blocking = local auditable blocklist (`require_nofilter = true`), `blocked_query_response = 'refused'`, `enable_hot_reload = true`.
- [x] Container network named `dnscrypt-tor` / 10.250.53.0/24 to avoid clashing with `dnscrypt.network` (10.89.0.0/24) in [[dnscrypt-proxy-podman]].
- [x] No container publishes `:53`; the native daemon keeps `127.0.0.1:53`.
- [x] Own image: prefer §3a (klutchell + baked config); §3b combined Alpine tor+dnscrypt as an optional appliance.

## Outstanding deploy steps (need user, sudo)

- [ ] Back up `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` before editing.
- [ ] Add `/etc/torrc.d/dnscrypt.conf` (SocksPort 9052) + `enable --now tor.service`.
- [ ] Add `force_tcp`/`proxy` to the native config; add `dnscrypt-proxy.service.d/20-tor.conf` ordering.
- [ ] **Fix the leak:** `nmcli con mod … ipv4.dns 127.0.0.1` + `ignore-auto-dns yes` + `dns-priority -50`.
- [ ] Install the blocklist refresh timer (§7); fill `allowed-names.txt`.
- [ ] Optional: build + run the container stack (§5) and attach consumers.
- [ ] Run the Verification section and paste results back; move the note from `draft`.

## Report for the user (coexistence)

- Do not publish new containers on `53`, `9050`, `8118`, `9081`.
- Do not edit/rename `searxng*.container|network|volume`; DNS must not depend on the search stack.
- If the host is ever switched to the container resolver, stop the native service first and set `ip_unprivileged_port_start=53`.

## Rollback

See the Rollback section of [[dnscrypt-proxy-tor]]. Short form: remove `20-tor.conf`, revert
the two keys, `disable --now tor.service`, restore NM auto-DNS, remove the `dnscrypt-tor`
user units and network.

## Next action for the user

Run §6.1–§6.3 (Tor + config + NetworkManager), then the Verification section steps 1–6 and
paste the output here.

---
title: "dnscrypt-proxy over Tor — Host and Container Deployment"
aliases:
  - dnscrypt-proxy tor
  - dnscrypt over tor
  - tor dns
  - dnscrypt-proxy quadlet tor
  - encrypted dns over tor
  - adblock dns container
description: >-
  Route dnscrypt-proxy's upstream traffic through Tor on one host, for both the native
  system daemon and a rootless Quadlet container: the TCP-only `force_tcp` + `proxy`
  settings, an isolated Tor circuit, a scratch or Alpine-built image, network-scoped DNS
  for other containers, the NetworkManager hand-off the host is currently missing, and a
  fail-closed ad-blocking configuration. Coexistence rules for the existing searxng/tor
  stack are in the collision report; the untorified variants live in
  [[arch-dnscrypt-proxy]] and [[dnscrypt-proxy-podman]].
tags:
  - containers
  - podman
  - quadlet
  - systemd
  - arch-linux
  - linux
  - dns
  - dns-over-https
  - dnscrypt
  - adblocking
  - networking
  - privacy
  - security
  - sandboxing
  - tor
  - anonymity
type: runbook
status: draft
created: 2026-10-14
updated: 2026-10-14
last_reviewed: 2026-10-14
review_after: 2027-04-14
language: en
audience: sysadmin
scope: >-
  Composing dnscrypt-proxy with a Tor SOCKS egress so that *upstream* DNS rides Tor, for
  the native system daemon and for a rootless Quadlet container, plus the blocklist
  operations and the collision rules against the running searxng stack. The untorified
  container mechanics are in [[dnscrypt-proxy-podman]]; resolver choice, the systemd
  sandbox drop-in and the NetworkManager keys are documented in [[arch-dnscrypt-proxy]].
platform:
  - arch-linux
  - podman
  - systemd
keywords:
  - force_tcp
  - proxy socks5
  - isolated circuit
  - socks5h
  - klutchell/dnscrypt-proxy
  - jauderho/dnscrypt-proxy
  - Containerfile
  - blocked_query_response
  - refused
  - enable_hot_reload
  - require_nofilter
  - network-scoped DNS
  - aardvark-dns
  - ip_unprivileged_port_start
sources:
  - "[dnscrypt-proxy 2.1.18 example configuration — proxy, force_tcp, blocked_query_response, enable_hot_reload](https://github.com/DNSCrypt/dnscrypt-proxy/blob/2.1.18/dnscrypt-proxy/example-dnscrypt-proxy.toml)"
  - "[DNSCrypt wiki — Anonymized DNS (alternatives to Tor routing)](https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Anonymized-DNS)"
  - "[klutchell/dnscrypt-proxy — README and Dockerfile (scratch, uid 65532, /config, dnsprobe)](https://github.com/klutchell/dnscrypt-proxy)"
  - "[jauderho/dnscrypt-proxy — semver-tagged multi-arch image](https://hub.docker.com/r/jauderho/dnscrypt-proxy/tags)"
  - "[Alpine v3.22 community: dnscrypt-proxy 2.1.13-r4](https://pkgs.alpinelinux.org/package/v3.22/community/x86_64/dnscrypt-proxy)"
  - "[Alpine v3.22 community: tor 0.4.9.14-r0](https://pkgs.alpinelinux.org/package/v3.22/community/x86_64/tor)"
  - "[podman-systemd.unit(5) — Quadlet [Container], [Network], [Pod], drop-ins](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)"
  - "[podman-network-create(1) — --dns and the aardvark-dns forwarding contract](https://docs.podman.io/en/latest/markdown/podman-network-create.1.html)"
  - "[ArchWiki: Tor — client SocksPort, torrc, systemd unit](https://wiki.archlinux.org/title/Tor)"
  - "[nm-settings-nmcli(5) — ipv4.dns, ignore-auto-dns, dns-priority](https://man.archlinux.org/man/nm-settings-nmcli.5.en)"
source_retrieved: 2026-10-14
related:
  - "[[arch-dnscrypt-proxy]]"
  - "[[dnscrypt-proxy-podman]]"
  - "[[tor]]"
  - "[[searxng-tor]]"
  - "[[Quadlet]]"
  - "[[podlet-compose-to-quadlet]]"
  - "[[podman-registries]]"
  - "[[container-registries]]"
  - "[[NetworkManager]]"
  - "[[DNS-over-HTTPS]]"
  - "[[Home]]"
  - "[[Vault Conventions]]"
cssclasses:
  - nota-longa
  - wide-table
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Write a vault note on running dnscrypt-proxy over Tor for host and containers, with a self-built image and the safest ad-blocking config, without breaking the existing searxng Quadlet stack"
ai-review: pending
---

# dnscrypt-proxy over Tor — Host and Container Deployment

> [!summary] One-paragraph answer
> dnscrypt-proxy can send **every** upstream connection through a Tor SOCKS proxy: set
> `force_tcp = true` (Tor carries no UDP) and `proxy = 'socks5://dnscrypt:dnscrypt@HOST:9050'`.
> The arbitrary user/pass is not a credential — Tor uses it to hand the proxy its **own
> isolated circuit**, so DNS does not share an exit with the browser. On this host the
> native `dnscrypt-proxy.service` is already running and answering on `127.0.0.1:53`, but
> `/etc/resolv.conf` still points at the ISP (`187.33.208.9`) — so nothing is actually
> using it yet; the missing step is the NetworkManager hand-off, and the Tor hop is one
> config edit plus a Tor client. For containers, run a Tor sidecar and a dnscrypt-proxy
> container on a dedicated network and put the resolver's address in `[Network] DNS=`, so
> every attached container inherits encrypted, Tor-routed, ad-blocked resolution with no
> per-container configuration. Prefer building your own image (`FROM` the scratch upstream
> image with the config baked in, or an Alpine image that carries Tor **and** dnscrypt-proxy),
> and keep the ad-blocking layer local and auditable with `blocked_query_response = 'refused'`.

> [!note] How this note relates to the other two dnscrypt notes
> [[arch-dnscrypt-proxy]] is the **native** install without Tor (socket vs service,
> sandbox drop-in, `nmcli` hand-off). [[dnscrypt-proxy-podman]] is the **container**
> install without Tor (`keep-id`, `ip_unprivileged_port_start`, `dnsprobe`, network-scoped
> DNS). This note is the **composition**: dnscrypt-proxy *plus* Tor, for host and
> containers together, with the collision rules against the running searxng stack. Where a
> mechanic already lives in those notes it is cross-linked, not repeated.

> [!caution] Status of this note
> The **current host state** in §1 is verified — it was read live from `bacon` (Podman
> 6.1.3, native `dnscrypt-proxy.service` active). The **Tor-routed deployment** in
> §4–§6 is `draft`: every key was checked against the upstream 2.1.18 example config and
> the Quadlet/network docs, but the end-to-end Tor cut-over has not been executed on this
> host, because the native daemon currently owns `127.0.0.1:53`. Treat the units as a
> reviewed starting point, run the Verification section, and update this note with what
> actually happened.

## Context

You want DNS that is encrypted, ad-blocked and **not attributable** — so the resolver
cannot see your IP and your ISP cannot see your queries. Encrypted DNS (DoH/DNSCrypt)
solves the second problem but not the first: the resolver still learns who you are. Routing
the encrypted hop through Tor removes that.

The goal on this machine is specific: **dnscrypt-proxy everywhere, Tor by default** — the
native daemon for the host, and a container for other containers — without disturbing the
running searxng stack, which already has its own Tor sidecar on `127.0.0.1:9050`.

Four facts shape the design:

- **Tor is TCP-only.** The proxy's UDP path must be disabled; `force_tcp = true` is
  mandatory, not a latency tweak.
- **Port 53 is a single-occupancy resource.** The native daemon already holds
  `127.0.0.1:53`; a container that publishes it would collide.
- **Isolation is cheap.** A random SOCKS user/pass gives dnscrypt-proxy a dedicated Tor
  circuit, so DNS exits do not overlap with the browser or SearXNG.
- **Fail-closed is the point.** If Tor is down, DNS should fail — not silently fall back
  to cleartext.

Reference host state at time of writing (Arch, Podman 6.1.3, cgroup v2): the native
`dnscrypt-proxy.service` is active and enabled on `127.0.0.1:53` + `[::1]:53`; the socket
unit is disabled; `tor.service` is inactive; the `searxng-tor` container publishes
`127.0.0.1:9050` and `127.0.0.1:8118`; user lingering is on.

## Details

### 1. Current host state — the report before changing anything

Read live from `bacon`. Nothing below was modified by the agent.

| Check | Reading | Meaning |
|---|---|---|
| `podman --version` | `6.1.3` | Quadlet + `keep-id` + `Notify=healthy` all available |
| `systemctl is-enabled dnscrypt-proxy.socket dnscrypt-proxy.service` | `disabled` / `enabled` | **service mode**, one owner of :53 |
| `ss -lpn 'sport = :domain'` | `127.0.0.1:53`, `[::1]:53` (tcp+udp+mptcp) | the native daemon owns :53 |
| `cat /etc/resolv.conf` | `nameserver 187.33.208.9`, `nameserver 8.8.8.8` | **the host is not using the local proxy** |
| `dnscrypt-proxy.toml` | `force_tcp = false`, no `proxy` | **upstream is direct, not Tor** |
| `dnscrypt-proxy.toml` | `blocked_names_file = /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.txt` (8.9 MB) | local ad-blocklist is wired |
| `…/dnscrypt-proxy.service.d/override.conf` | `ProtectProc`, `ProtectClock`, `SocketBindDeny=any`, `SocketBindAllow=udp:53 tcp:53` | sandbox drop-in present |
| `tor.service` | `inactive` | no host Tor; only the containerised one |
| `podman ps` | `searxng` (127.0.0.1:9081), `searxng-valkey`, `searxng-tor` (127.0.0.1:9050/8118) | the stack to protect |
| `podman network ls` | `podman` 10.88.0.0/16, `systemd-searxng` 10.247.1.0/24 | pick an unused subnet |
| `sysctl net.ipv4.ip_unprivileged_port_start` | `1024` | publishing host :53 rootless needs a sysctl |
| `loginctl show-user -p Linger` | `Linger=yes` | user Quadlets survive logout |

> [!important] The finding that matters most: DNS is leaking today
> `dnscrypt-proxy` is running and healthy — `dig @127.0.0.1 example.com` answers — yet
> `/etc/resolv.conf` hands applications `187.33.208.9` and `8.8.8.8`. The daemon is a
> bystander. Two separate problems are hidden in that one line: the host is not pointed at
> it (§6.3), and the daemon is not Tor-routed (§4). Fix both.

> [!note] Secondary finding: the blocklist is stale
> `~/.config/dnscrypt-proxy/dnscrypt-blocklist-domains.txt` (8.9 MB) and
> `/etc/dnscrypt-proxy/dnscrypt-blocklist-domains.txt` (8.9 MB) are dated early October,
> and no refresh timer exists under `~/.config/systemd/user/`. `enable_hot_reload` is also
> unset (default `false`), so even a manual rewrite would not take effect until a restart.
> §7 fixes both.

### 2. Where the Tor egress lives

Three placements work; they differ in blast radius and failure coupling.

| Placement | Best for | Coupling | Cost |
|---|---|---|---|
| **A. Host `tor.service`** (system) | the native daemon (§6) | DNS depends on the system Tor unit | one package, one port `9052` |
| **B. Dedicated DNS Tor container** | the container stack (§5) | DNS depends on that one container | one Quadlet unit |
| **C. Reuse `searxng-tor`'s `127.0.0.1:9050`** | a quick trial | stopping searxng breaks DNS | none — but couples the stacks |

> [!warning] Do not point production DNS at the searxng sidecar
> Option C is tempting because `127.0.0.1:9050` is already listening. But `searxng-tor`
> belongs to the searxng stack: a `podman restart searxng-tor`, an image update, or a
> `systemctl --user restart searxng` that bounces the sidecar will take DNS down with it.
> Use it to prove the concept, then move to A or B.

Pick **A** for the host daemon and **B** for the container network. They are independent,
so a problem in one does not cascade. Both use a **distinct port** (`9052` on the host,
container-internal `9050`), which is what keeps them clear of searxng's `9050`/`8118`.

### 3. The image — survey, then build your own

**There is no official dnscrypt-proxy client image.** The registry survey (`podman search
dnscrypt-proxy`) returns the community options; the ones worth knowing:

| Image | Shape | Use it when |
|---|---|---|
| `docker.io/klutchell/dnscrypt-proxy` | `FROM scratch`, `USER 65532`, `/config`, `dnsprobe` | you want the smallest, patch-free runtime (the existing [[dnscrypt-proxy-podman]] choice) |
| `docker.io/jauderho/dnscrypt-proxy` | Alpine-based, **semver tags** up to `2.1.18` | you want a pinnable tag without resolving a digest |
| `docker.io/vimagick/dnscrypt-proxy` | `FROM scratch` variant | alternative, less maintained |

> [!warning] `klutchell` publishes commit-SHA tags, not semver
> `podman search --list-tags docker.io/klutchell/dnscrypt-proxy` returns 40-char SHA tags
> and `latest` — no `2.1.18`. Pin it by **digest** if you need reproducibility:
> `podman inspect --format '{{.Digest}}' docker.io/klutchell/dnscrypt-proxy:latest`. If you
> prefer a human-readable pin, `jauderho/dnscrypt-proxy:2.1.18` is the one with semver tags
> (verified above).

#### 3a. Build a pinned config image (recommended, smallest)

Bake the config into `klutchell` so the running proxy is byte-for-byte reproducible from
your repo — no rw config mount at all.

```dockerfile
# Containerfile.dnscrypt  —  build: podman build -f Containerfile.dnscrypt -t dnscrypt-proxy:local .
FROM docker.io/klutchell/dnscrypt-proxy:latest

# The image is FROM scratch: uid/gid 65532, /config, ENTRYPOINT dnscrypt-proxy,
# CMD -config /config/dnscrypt-proxy.toml. Bake the config so nothing is bind-mounted.
#
# IMPORTANT: the image layer is read-only at runtime, so point cache_file at /tmp
# (ReadOnlyTmpfs is enabled by default and /tmp is writable + ephemeral). If you leave
# cache_file under /config, the fetch is re-done every boot and logs a write warning.
COPY config/dnscrypt-proxy.toml /config/dnscrypt-proxy.toml
COPY config/blocked-names.txt   /config/blocked-names.txt
COPY config/allowed-names.txt   /config/allowed-names.txt

USER 65532
```

```bash
podman build -f Containerfile.dnscrypt -t dnscrypt-proxy:local .
# podman stores it as localhost/dnscrypt-proxy:local — the exact name §5's unit references.
```

> [!tip] Baked config or rw config, not both
> Baking (§3a) gives a read-only, reproducible runtime with no `Volume=`. The rw-config
> layout in [[dnscrypt-proxy-podman]] instead lets the daemon rewrite its list cache and be
> fed a live blocklist. Pick one; each has a different `proxy` host — see §4.

#### 3b. Build a combined Tor + dnscrypt-proxy image (Tor by default in one container)

If you want a single self-contained appliance — no sidecar, no ordering — build both
daemons into one image. Both packages exist in Alpine v3.22 **community**: `dnscrypt-proxy`
and `tor` (verified). Note Alpine ships dnscrypt-proxy **2.1.13**, a few releases behind
Arch's 2.1.18 — fine for the `proxy`/`force_tcp` keys used here, but check the changelog
before relying on a newer option.

```dockerfile
# Containerfile.dnscrypt-tor
FROM docker.io/library/alpine:3.22
RUN apk add --no-cache dnscrypt-proxy tor tini \
 && mkdir -p /var/lib/tor /etc/dnscrypt-proxy /etc/tor \
 && chown -R tor:tor /var/lib/tor
COPY config/dnscrypt-proxy.toml /etc/dnscrypt-proxy/dnscrypt-proxy.toml
COPY config/blocked-names.txt   /etc/dnscrypt-proxy/blocked-names.txt
COPY config/allowed-names.txt   /etc/dnscrypt-proxy/allowed-names.txt
COPY config/torrc               /etc/tor/torrc
COPY entrypoint.sh              /usr/local/bin/entrypoint.sh
RUN chmod 0755 /usr/local/bin/entrypoint.sh
EXPOSE 53/tcp 53/udp
ENTRYPOINT ["/sbin/tini","--","/usr/local/bin/entrypoint.sh"]
```

`config/torrc` — client only, no relay, SOCKS on the container loopback:

```
SocksPort 127.0.0.1:9050
ControlPort 0
DataDirectory /var/lib/tor
User tor
ExitRelay 0
SocksPort 0
```

`entrypoint.sh` — Tor first, wait for its SOCKS port, then hand off to the proxy:

```sh
#!/bin/sh
set -eu
tor -f /etc/tor/torrc &
i=0
while [ "$i" -lt 90 ]; do
  if nc -w 1 127.0.0.1 9050 </dev/null >/dev/null 2>&1; then break; fi
  i=$((i + 1)); sleep 1
done
[ "$i" -lt 90 ] || { echo "tor did not open 9050 in 90s" >&2; exit 1; }
exec dnscrypt-proxy -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

```bash
podman build -f Containerfile.dnscrypt-tor -t dnscrypt-tor:local .
```

> [!caution] Two daemons, one PID 1 — an appliance, not a pattern
> Running Tor and dnscrypt-proxy under one `tini` works, and the `nc` wait makes startup
> ordered, but it is the one thing container runtimes discourage: two responsibilities,
> one container. Prefer the **pod** in §5 or the two-container network layout if you value
> maintainability. Keep this image for a throwaway box or a single-file appliance.

### 4. The safest `dnscrypt-proxy.toml`

The full global block, tuned for Tor with fail-closed ad-blocking. Keys marked ⟂ are the
ones that change relative to a direct-Ethernet setup.

```toml
## --- Tor egress -------------------------------------------------------------------
## Tor carries no UDP, so TCP is mandatory whenever proxy= is set.
force_tcp = true
## All TCP connections (queries *and* source-list fetches) go through this SOCKS proxy.
## The user/pass are arbitrary; Tor uses them to assign an ISOLATED CIRCUIT so DNS does
## not share an exit node with any other application. Do NOT define them in torrc.
## This value targets the NATIVE host daemon via §6 (tor.service on 9052). The container
## and combined-image call sites differ — see the table after this block.
proxy = 'socks5://dnscrypt:dnscrypt@127.0.0.1:9052'
## HTTP/3 is QUIC-over-UDP and cannot ride Tor.
http3 = false

## --- Listener (container uses 0.0.0.0; native host uses loopback) ------------------
listen_addresses = ['0.0.0.0:53']    # container form; native: ['127.0.0.1:53', '[::1]:53']
max_clients = 250
## Tor adds latency: 5000 is the floor, 10000 is the highest reasonable value.
timeout = 10000
keepalive = 30

## --- Server selection -------------------------------------------------------------
server_names = []            # let the require_* filters choose; pinning bypasses them
ipv4_servers = true
ipv6_servers = false         # no working IPv6 → stalls queries
dnscrypt_servers = true
doh_servers = true
odoh_servers = false         # redundant: Tor already hides the client from the resolver
require_dnssec = true        # prefer DNSSEC-validating resolvers (not local validation)
require_nolog = true
require_nofilter = true      # the LOCAL blocklist is the single, auditable ad-block layer
disabled_server_names = []

## --- Filtering & privacy ----------------------------------------------------------
block_unqualified = true
block_undelegated = true
block_ipv6 = false
## `refused` is fail-closed and honest; the default `hinfo` returns a fabricated answer
## ("some responses will be lies"). Android 8+ needs `hinfo` — desktop does not.
blocked_query_response = 'refused'
reject_ttl = 10
## Apply edits to blocked-names.txt without a restart.
enable_hot_reload = true
## Optional hardening: never reuse a TLS session ticket (small latency cost).
# tls_disable_session_tickets = true
## Optional: a fresh X25519 key per query (CPU cost; only on low-traffic hosts).
# dnscrypt_ephemeral_keys = true

## --- Startup & cache --------------------------------------------------------------
bootstrap_resolvers = ['9.9.9.11:53', '8.8.8.8:53']
ignore_system_dns = true
netprobe_timeout = 60
netprobe_address = '9.9.9.9:53'
cache = true
cache_size = 4096
cache_min_ttl = 2400
cache_max_ttl = 86400
cache_neg_min_ttl = 60
cache_neg_max_ttl = 600

## --- Ad-blocking layers -----------------------------------------------------------
[blocked_names]
blocked_names_file = '/config/blocked-names.txt'   # native: /etc/dnscrypt-proxy/…
log_file = '/tmp/blocked-names.log'   # rw path (baked image); native: /var/log/dnscrypt-proxy/…

[allowed_names]
allowed_names_file = '/config/allowed-names.txt'   # undo collateral damage; fill it

[sources.public-resolvers]
urls = [
  'https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md',
  'https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md',
]
cache_file = '/tmp/public-resolvers.md'            # container: rw tmpfs; native: /var/cache/dnscrypt-proxy/public-resolvers.md
minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
refresh_delay = 73
prefix = ''
```

Three call sites, three `proxy` values — pick the one matching where the daemon runs:

| Where the daemon runs | `proxy` value |
|---|---|
| Native host daemon (§6), Tor on `9052` | `'socks5://dnscrypt:dnscrypt@127.0.0.1:9052'` |
| **Container** (§5), sidecar named `dnscrypt-tor` on the podman network | `'socks5://dnscrypt:dnscrypt@dnscrypt-tor:9050'` |
| Combined tor+dnscrypt image (§3b) | `'socks5://dnscrypt:dnscrypt@127.0.0.1:9050'` |

The container value resolves `dnscrypt-tor` through aardvark-dns on the shared network. Do
not use `127.0.0.1` there — inside a container that is the container itself.

Validate without starting anything — the scratch image still has the binary:

```bash
podman run --rm -v "$PWD/config:/config:Z" \
  docker.io/klutchell/dnscrypt-proxy -check -config /config/dnscrypt-proxy.toml
# -> Configuration successfully checked
```

Fine-tuning, and the value to prefer on a Tor-routed host:

| Key | Default | Set to | Why |
|---|---|---|---|
| `timeout` | 5000 | **10000** | Tor circuit latency; 5000 is the floor |
| `force_tcp` ⟂ | false | **true** | required — Tor has no UDP |
| `proxy` ⟂ | unset | **socks5://…@127.0.0.1:9050** | the whole point; isolated circuit |
| `http3` | false | false | UDP; incompatible with Tor |
| `odoh_servers` ⟂ | false | false | ODoH adds a relay layer Tor already provides |
| `require_nofilter` | true | **true** | keep the filtering resolver out; block locally |
| `blocked_query_response` | `hinfo` | **`refused`** | no fabricated answers |
| `enable_hot_reload` | false | **true** | blocklist edits apply live |
| `lb_strategy` | `wp2` | `wp2` | weighted-power-of-two; leave unless you have data |
| `cert_refresh_delay` | 240 | 240 (min) | Tor makes cert refresh slow; do not shorten |
| `netprobe_address` | `9.9.9.9:53` | `9.9.9.9:443` | optional: keeps the boot connectivity probe off `:53` (TCP connect only) |

> [!warning] `require_*` are inert the moment you pin `server_names`
> If you later set `server_names = ['adguard-dns']`, `require_nofilter`/`require_dnssec`
> stop applying. With a local blocklist you want `require_nofilter = true` and an **empty**
> `server_names`, so the filter is what actually selects.

> [!caution] The bootstrap lookup is a small, unavoidable leak
> With `ignore_system_dns = true` and no resolver yet loaded, dnscrypt-proxy resolves the
> **source-list hostnames** (`raw.githubusercontent.com`, …) through `bootstrap_resolvers`
> in cleartext, *before* it has an encrypted path — the user queries never go there, but the
> list fetch reveals that the host is fetching a resolver list. Mitigate by keeping the
> cache warm (`cache_file` on a persistent path) so the fetch happens rarely, or accept it;
> it is metadata, not query content.

### 5. Container deployment — Quadlet, network-scoped DNS

A dedicated network carries the resolver so every attached container inherits it. Subnet
`10.250.53.0/24` is chosen deliberately: it is **outside** the live `podman`
(`10.88.0.0/16`) and `systemd-searxng` (`10.247.1.0/24`) pools, and distinct from
[[dnscrypt-proxy-podman]]'s `dnscrypt.network` (10.89.0.0/24), so the two notes' units can
coexist without clobbering.

`~/.config/containers/systemd/dnscrypt-tor.network`:

```ini
[Network]
NetworkName=dnscrypt-tor
Subnet=10.250.53.0/24
Gateway=10.250.53.1
# Network-scoped resolver: aardvark-dns forwards every non-container name to .2:53.
DNS=10.250.53.2
```

`~/.config/containers/systemd/dnscrypt-tor.container` — the egress, internal only:

```ini
[Container]
ContainerName=dnscrypt-tor
Image=docker.io/dperson/torproxy:latest
Network=dnscrypt-tor.network
IP=10.250.53.3
# Deliberately NO PublishPort: the SOCKS proxy is reachable only on this network.
HealthCmd=["CMD","nc","-z","127.0.0.1","9050"]
HealthInterval=30s
HealthTimeout=5s
HealthRetries=3
HealthStartPeriod=60s
Notify=healthy
LogDriver=journald

[Service]
Restart=always
RestartSec=5
MemoryMax=512M

[Install]
WantedBy=default.target
```

`~/.config/containers/systemd/dnscrypt-proxy.container`:

```ini
[Unit]
Description=dnscrypt-proxy over Tor — encrypted ad-blocked DNS
# Wait for the sidecar to be *healthy*, not merely started (Notify=healthy + After=).
Requires=dnscrypt-tor.service
After=dnscrypt-tor.service

[Container]
ContainerName=dnscrypt-proxy
Image=localhost/dnscrypt-proxy:local          # from §3a; or docker.io/klutchell/dnscrypt-proxy
Network=dnscrypt-tor.network
IP=10.250.53.2

# Nonroot image (uid 65532): keep-id makes the rw config dir writable and files come back yours.
UserNS=keep-id:uid=65532,gid=65532
# Let the nonroot process bind :53 inside its own netns (no capability needed).
Sysctl=net.ipv4.ip_unprivileged_port_start=0

# NO PublishPort: the native daemon owns 127.0.0.1:53 on this host (see §8).

ReadOnly=true
DropCapability=all
NoNewPrivileges=true

HealthCmd=["/usr/local/bin/dnsprobe","example.com","127.0.0.1:53"]
HealthInterval=30s
HealthTimeout=3s
HealthRetries=3
HealthStartPeriod=60s
Notify=healthy
# AutoUpdate=registry only if Image= is a registry tag; omit it for the local build (§3a).
LogDriver=journald

[Service]
Restart=always
RestartSec=5
TimeoutStartSec=900

[Install]
WantedBy=default.target
```

If you bake the config (§3a) you can drop the `Volume=` line entirely; if you keep a rw
config dir instead, add:

```ini
Volume=/home/USER/.config/dnscrypt-proxy:/config:Z
```

Bring it up and attach a consumer:

```bash
systemctl --user daemon-reload
systemctl --user start dnscrypt-proxy.service
systemctl --user status dnscrypt-proxy.service
# any container on the network now resolves through it:
podman run --rm --network systemd-dnscrypt-tor docker.io/library/alpine:latest \
  sh -c 'cat /etc/resolv.conf; nslookup example.com'
```

> [!important] How network-scoped DNS actually routes
> On a network with `dns_enabled`, a container's `resolv.conf` points **only** at
> aardvark-dns (`10.250.53.1`), and aardvark forwards every non-container name to the
> supplied `DNS=` address on **port 53**. That is why the container must listen on
> `0.0.0.0:53`, not the image's default `5053` — a static IP alone is not enough.

### 6. Host deployment — native daemon, Tor over `tor.service`

#### 6.1 A host Tor client on a distinct port

```bash
sudo pacman -S tor
sudo tee /etc/torrc.d/dnscrypt.conf >/dev/null <<'EOF'
# DNS egress only. Distinct port so it never collides with searxng-tor's 9050.
SocksPort 127.0.0.1:9052
ControlPort 0
ExitRelay 0
EOF
sudo systemctl enable --now tor.service
```

The system unit already carries `Wants=network-online.target`, so ordering into the boot
sequence is clean — unlike a user container, which the system daemon cannot depend on.

#### 6.2 Point the native daemon at Tor

Edit `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` (back it up first):

```toml
force_tcp = true
proxy = 'socks5://dnscrypt:dnscrypt@127.0.0.1:9052'
http3 = false
```

Then make the dependency explicit in the existing drop-in, so DNS starts only after Tor:

```bash
sudo tee /etc/systemd/system/dnscrypt-proxy.service.d/20-tor.conf >/dev/null <<'EOF'
[Unit]
After=tor.service
Wants=tor.service
EOF
sudo systemctl daemon-reload
```

`SocketBindAllow=udp:53 tcp:53` in the existing `override.conf` still permits the listener;
`proxy`/`force_tcp` add only outbound `connect(2)` calls, which `SocketBind*` does not
restrict. No sandbox change is needed.

#### 6.3 The step the host is missing today — NetworkManager hand-off

Until `resolv.conf` points at loopback, none of the above reaches applications. Follow
[[arch-dnscrypt-proxy]] §7 in full; the short form:

```bash
CON="$(nmcli -t -f NAME,DEVICE con show --active | awk -F: '$2 !~ /^(lo|virbr|veth|docker|br-)/ {print $1; exit}')"
nmcli con mod "$CON" \
  ipv4.dns "127.0.0.1" ipv4.ignore-auto-dns yes \
  ipv6.dns "::1"        ipv6.ignore-auto-dns yes \
  ipv4.dns-options "edns0 trust-ad" \
  ipv4.dns-priority -50
nmcli con up "$CON"
```

`ignore-auto-dns yes` drops the DHCP-provided `187.33.208.9`/`8.8.8.8`; `dns-priority -50`
keeps a VPN from overriding the local resolver.

> [!warning] Fail-closed means Tor must be up at boot
> Once `proxy` is set, DNS is dead without Tor. `tor.service` is `enabled`, and §6.2 makes
> `dnscrypt-proxy` wait for it, so the common boot order is fine. If Tor is ever stopped by
> hand, expect *all* name resolution to fail, not to degrade to the ISP resolver — that is
> the intended behaviour.

### 7. Ad-blocking — the two layers, and keeping them fresh

**Layer A — the local, auditable blocklist.** The live config already points
`blocked_names_file` at an 8.9 MB generated list. Rebuild it with the packaged helper:

```bash
cd /usr/share/dnscrypt-proxy/utils/generate-domains-blocklist
sudo generate-domains-blocklist \
  --config domains-blocklist.conf \
  --allowlist domains-allowlist.txt \
  --time-restricted domains-time-restricted.txt \
  --output-file /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.new
sudo mv -f /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.new \
           /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.txt
```

**Layer B — a filtering resolver.** Optional, and mutually informative: with
`require_nofilter = false` you also accept upstream-filtering resolvers, catching
first-party trackers a public feed misses. The trade-off is losing the "one auditable
list" property, which is why the safe default here is `true` and a local list.

Refresh it with a timer, and write to `.new` then `mv` so the daemon never reads a
half-written file. `enable_hot_reload = true` (§4) makes the rename take effect with no
restart:

```bash
sudo tee /etc/systemd/system/dnscrypt-proxy-blocklist.service >/dev/null <<'EOF'
[Unit]
Description=Regenerate the dnscrypt-proxy local blocklist
[Service]
Type=oneshot
WorkingDirectory=/usr/share/dnscrypt-proxy/utils/generate-domains-blocklist
ExecStart=/usr/bin/generate-domains-blocklist -c domains-blocklist.conf -a domains-allowlist.txt -r domains-time-restricted.txt -o /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.new
ExecStart=/usr/bin/mv -f /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.new /etc/dnscrypt-proxy/dnscrypt-blocklist-domains.txt
EOF
sudo tee /etc/systemd/system/dnscrypt-proxy-blocklist.timer >/dev/null <<'EOF'
[Unit]
Description=Daily dnscrypt-proxy blocklist refresh
[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h
[Install]
WantedBy=timers.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable --now dnscrypt-proxy-blocklist.timer
```

Fill `allowed-names.txt` **before** going live: the first casualty of a fresh blocklist is
usually a login or CDN, and the allowlist is how you undo it without disabling the layer.

### 8. Coexistence — what not to touch

The running searxng stack (`~/.config/containers/systemd/searxng*.{container,network,volume}`)
must keep working. The rules that follow from the live state:

| Resource | Currently held by | This note | Safe? |
|---|---|---|---|
| `127.0.0.1:53` (tcp+udp) | native `dnscrypt-proxy.service` | container does **not** publish :53 | ✅ |
| `127.0.0.1:9050` | `searxng-tor` container | host Tor uses **9052**; container Tor stays internal | ✅ |
| `127.0.0.1:8118` | `searxng-tor` (Privoxy) | untouched | ✅ |
| `127.0.0.1:9081` | `searxng` | untouched | ✅ |
| `10.247.1.0/24` (`systemd-searxng`) | searxng network | new network uses `10.250.53.0/24` | ✅ |
| `10.88.0.0/16` (`podman` default) | podman | outside the chosen subnet | ✅ |
| `/etc/dnscrypt-proxy/*` | native daemon | edits are additive keys only | ✅ |

Do **not**:

- publish any new container on `9050`, `8118`, `53`, or `9081`;
- rename or edit `searxng.network`/`searxng-tor.container` — DNS should not depend on the
  search stack;
- `systemctl --user restart searxng-tor` to "refresh DNS" — that is the coupling §2 warns
  about;
- run the native daemon and a container-published `:53` at once. If you ever *do* want the
  host to use the container resolver, stop the native service first:

  ```bash
  sudo systemctl disable --now dnscrypt-proxy.service dnscrypt-proxy.socket
  sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53   # rootless publish of :53
  ```

> [!caution] The two `dnscrypt-proxy` notes must not define the same network name
> [[dnscrypt-proxy-podman]] declares `dnscrypt.network` / `10.89.0.0/24`. This note uses
> `dnscrypt-tor.network` / `10.250.53.0/24` on purpose. Defining both corpora verbatim
> would leave two units competing for one network name — pick one deployment, or keep the
> subnets and unit names distinct as shown.

## Gotchas

> [!danger] Without `force_tcp`, Tor cannot carry the traffic
> `proxy` alone is not enough — the proxy defaults to UDP for DNSCrypt and QUIC for HTTP/3,
> neither of which Tor forwards. The symptom is a proxy that connects and then times out on
> every query. `force_tcp = true` and `http3 = false` are both required.

> [!warning] `allow_insecure`/plaintext is *not* the fallback you want
> There is no graceful downgrade once `proxy` is set and Tor is down. If you need DNS to
> survive a Tor outage, run a second, non-anonymous resolver and switch deliberately — do
> not expect dnscrypt-proxy to leak automatically. Automatic cleartext fallback would
> defeat the purpose.

> [!warning] A published Tor SOCKS port is an open proxy
> The `searxng-tor` unit publishes `127.0.0.1:9050` (loopback only — fine). Never widen
> that to `0.0.0.0`, and never publish the DNS network's Tor sidecar at all.

> [!caution] `blocked_query_response = 'refused'` breaks `dig`-expects-NXDOMAIN tests
> A locally blocked name returns `REFUSED`, not `NXDOMAIN`. The definitive proof your layer
> fired is an entry in `[blocked_names] log_file`, not the `dig` status.

> [!warning] Editing the blocklist changes nothing unless hot reload is on
> `enable_hot_reload` defaults to **false**. A nightly rebuild leaves the daemon on the old
> rules until a restart — silently.

> [!caution] `localhost` inside the container is the container
> In the two-container layout the Tor host is the **container name** on the shared network
> (`socks5://…@dnscrypt-tor:9050`), not `127.0.0.1`. `127.0.0.1` only works for the combined
> image (§3b) or the host daemon (§6), where the proxy really is local.

> [!note] Quadlet units are transient — `systemctl enable` will refuse
> Keep `[Install] WantedBy=default.target` in each unit; `systemctl --user enable foo.service`
> errors with "transient". For boot-without-login, `loginctl enable-linger "$USER"` (already
> on here).

> [!caution] Quadlet networks are named `systemd-<NetworkName>`
> The generated network is `systemd-dnscrypt-tor`, not `dnscrypt-tor` — verified on this host,
> where `searxng.network` appears as `systemd-searxng` in `podman network ls`. The Quadlet
> units are unaffected (they reference the `.network` file), but manual `podman run --network …`
> and `podman network rm` must use the prefixed name, as §5 and Rollback already do.

> [!warning] First Tor start is slow and can exceed systemd's start timeout
> `HealthStartPeriod=60s` plus `[Service] TimeoutStartSec=900` absorbs the cold bootstrap
> and the resolver-list fetch. If a name is "not found", the generator rejected the unit —
> run `/usr/lib/podman/quadlet -dryrun -user` (see [[Quadlet]]).

> [!note] `odoh_servers` over Tor is redundant, not harmful
> The live config has `odoh_servers = true` with ODoH sources configured. Through Tor the
> client is already hidden from the resolver, so ODoH adds latency for no extra anonymity.
> Set it false unless you have a specific ODoH reason.

## Verification

```bash
# 1. the isolated circuit exists: Tor should show a SOCKS connection from dnscrypt-proxy
sudo journalctl -u tor.service --no-pager -n 30 | grep -i socks
ss -tnp | grep ':9052'           # an established connection while a query is in flight

# 2. egress really is Tor (the exit IP is a relay, not your ISP)
curl -s --socks5-hostname 127.0.0.1:9052 https://check.torproject.org/api/ip
# expect: {"IsTor":true, ...}

# 3. the native daemon still resolves, now via the proxy
dig +short @127.0.0.1 example.com

# 4. the host is pointed at the proxy — the fix for the §1 leak
cat /etc/resolv.conf
# expect: nameserver 127.0.0.1  (still "# Generated by NetworkManager" — that is correct)

# 5. ad-blocking fires, and you can attribute it
dig @127.0.0.1 pagead2.googlesyndication.com
sudo tail -5 /var/log/dnscrypt-proxy/blocked-names.log

# 6. nothing leaks to the ISP on :53 (bootstrap/netprobe touches aside — see below)
sudo tcpdump -ni any 'port 53 and not host 127.0.0.1 and not port 9052'
# expect: silence in steady state

# 7. container path: inherit the resolver, resolve, and prove Tor
podman run --rm --network systemd-dnscrypt-tor docker.io/library/alpine:latest \
  sh -c 'cat /etc/resolv.conf; nslookup example.com'
podman exec dnscrypt-proxy /usr/local/bin/dnsprobe example.com 127.0.0.1:53
```

Expected readings:

- Step 2: `"IsTor": true`. `false` means the proxy host/port is wrong; a connection error
  means Tor is not up.
- Step 4: `nameserver 127.0.0.1` replaces `187.33.208.9`/`8.8.8.8`.
- Step 5: an answer with no records (`refused`), plus a fresh line in `blocked-names.log`.
- Step 6: steady-state silence. Two brief exceptions are expected and harmless — the
  `bootstrap_resolvers` lookup when a source list refreshes, and the `netprobe_address`
  connect at startup (§4). Both are metadata touches, never query content. Anything else is
  a client bypassing the resolver; find it before trusting the setup.

## Rollback

```bash
# host: drop the Tor hop
sudo rm /etc/systemd/system/dnscrypt-proxy.service.d/20-tor.conf
#   edit /etc/dnscrypt-proxy/dnscrypt-proxy.toml: force_tcp=false, remove proxy=
sudo systemctl daemon-reload && sudo systemctl restart dnscrypt-proxy.service
sudo systemctl disable --now tor.service            # only if you added it

# host: restore DHCP DNS (undo §6.3)
nmcli con mod "$CON" ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no \
  ipv4.dns "" ipv6.dns "" && nmcli con up "$CON"

# containers
systemctl --user stop dnscrypt-proxy.service dnscrypt-tor.service
rm ~/.config/containers/systemd/dnscrypt-tor.{network,container} \
   ~/.config/containers/systemd/dnscrypt-proxy.container
systemctl --user daemon-reload
podman network rm systemd-dnscrypt-tor 2>/dev/null || true
```

## Related

- [[arch-dnscrypt-proxy]] — the native install without Tor: activation mode, resolver
  choice, the sandbox drop-in, and the full NetworkManager hand-off
- [[dnscrypt-proxy-podman]] — the container install without Tor: `keep-id`,
  `ip_unprivileged_port_start`, `dnsprobe`, network-scoped DNS
- [[tor]] — the daemon side: `socks5` vs `socks5h`, ControlPort, `torrc` include layout
- [[searxng-tor]] — the other Tor-routed stack; the stack this note must not disturb
- [[Quadlet]] · [[podlet-compose-to-quadlet]] — unit keys, drop-ins, and generating units
- [[podman-registries]] · [[container-registries]] — resolving the fully-qualified image names
- [[NetworkManager]] — connection-profile DNS properties in depth
- [[DNS-over-HTTPS]] — protocol and stamp background
- [[Vault Conventions]] — the schema this note follows

## Sources

- [dnscrypt-proxy 2.1.18 example configuration](https://github.com/DNSCrypt/dnscrypt-proxy/blob/2.1.18/dnscrypt-proxy/example-dnscrypt-proxy.toml) —
  `force_tcp` ("route everything through Tor"), the `proxy` SOCKS line and isolated-circuit
  note, `http3`, `blocked_query_response`, `enable_hot_reload`, `[blocked_names]`,
  `[sources]` and the `require_*` filter behaviour
- [DNSCrypt wiki — Anonymized DNS](https://github.com/DNSCrypt/dnscrypt-proxy/wiki/Anonymized-DNS) —
  the relay approach this note treats as an alternative to Tor
- [klutchell/dnscrypt-proxy](https://github.com/klutchell/dnscrypt-proxy) — `FROM scratch`,
  uid 65532, `/config`, `dnsprobe`, and the "pin by digest" consequence
- [jauderho/dnscrypt-proxy tags](https://hub.docker.com/r/jauderho/dnscrypt-proxy/tags) —
  the semver-tagged alternative (`2.1.18`) verified via `podman search --list-tags`
- [Alpine `dnscrypt-proxy` 2.1.13-r4](https://pkgs.alpinelinux.org/package/v3.22/community/x86_64/dnscrypt-proxy) ·
  [Alpine `tor` 0.4.9.14-r0](https://pkgs.alpinelinux.org/package/v3.22/community/x86_64/tor) —
  the packages behind the combined §3b image
- [podman-systemd.unit(5)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) —
  `[Container]` (`Image`, `Network`, `IP`, `UserNS`, `Sysctl`, `ReadOnly`, `Notify`),
  `[Network] DNS=`, `[Install]`, transient-unit rules
- [podman-network-create(1)](https://docs.podman.io/en/latest/markdown/podman-network-create.1.html) —
  the aardvark-dns forward-on-53 contract
- [ArchWiki: Tor](https://wiki.archlinux.org/title/Tor) — client `SocksPort`, `torrc`
  `%include`, the shipped sandboxed unit
- [nm-settings-nmcli(5)](https://man.archlinux.org/man/nm-settings-nmcli.5.en) —
  `ipv4.dns`, `ignore-auto-dns`, `dns-priority`, `dns-options`

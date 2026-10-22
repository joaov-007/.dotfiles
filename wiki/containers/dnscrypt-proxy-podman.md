---
title: "dnscrypt-proxy in Podman — Encrypted DNS for Host and Containers"
aliases:
  - dnscrypt-proxy podman
  - dnscrypt-proxy container
  - containerized encrypted DNS
  - dnscrypt-proxy quadlet
  - rootless dnscrypt-proxy
description: >-
  Run dnscrypt-proxy as a rootless Podman container on one host: a scratch nonroot image,
  a rw ~/.config config dir, port 53 inside the container, network-scoped DNS for other
  containers, a published loopback port for host applications, and the [blocked_names]
  ad-blocking layer. The native package install is [[arch-dnscrypt-proxy]].
tags:
  - containers
  - podman
  - quadlet
  - podlet
  - systemd
  - arch-linux
  - linux
  - dns
  - dns-over-https
  - dnscrypt
  - adblocking
  - networking
  - networkmanager
  - security
  - privacy
  - sandboxing
type: runbook
status: draft
created: 2026-10-14
updated: 2026-10-14
last_reviewed: 2026-10-14
review_after: 2027-04-14
language: en
audience: sysadmin
scope: >-
  Containerizing the dnscrypt-proxy *client* with Podman and Quadlet on a single host: the
  rootless unit, the rw config dir, container DNS plumbing, and the host hand-off. The native
  `pacman` install, resolver choice and NetworkManager details live in [[arch-dnscrypt-proxy]],
  not here.
platform:
  - arch-linux
  - podman
  - systemd
keywords:
  - dnscrypt-proxy
  - klutchell/dnscrypt-proxy
  - podman
  - quadlet
  - podlet
  - aardvark-dns
  - keep-id
  - ip_unprivileged_port_start
  - blocked_names
  - blocked_query_response
  - enable_hot_reload
  - generate-domains-blocklist
  - network-scoped DNS
  - dnsprobe
sources:
  - "[klutchell/dnscrypt-proxy — README (usage, probes, config perms)](https://github.com/klutchell/dnscrypt-proxy)"
  - "[klutchell/dnscrypt-proxy — Dockerfile (scratch, nonroot 65532, /config)](https://github.com/klutchell/dnscrypt-proxy/blob/main/Dockerfile)"
  - "[klutchell/dnscrypt-proxy — shipped config/dnscrypt-proxy.toml](https://github.com/klutchell/dnscrypt-proxy/blob/main/config/dnscrypt-proxy.toml)"
  - "[podman-systemd.unit(5) — Quadlet [Container] keys, drop-ins, [Install]](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)"
  - "[podman-network.unit(5) — Quadlet [Network], DNS=](https://docs.podman.io/en/latest/markdown/podman-network.unit.5.html)"
  - "[podman-network-create(1) — --dns and aardvark-dns forwarding](https://docs.podman.io/en/latest/markdown/podman-network-create.1.html)"
  - "[podman-run(1) — --dns, --userns, --sysctl](https://docs.podman.io/en/latest/markdown/podman-run.1.html)"
  - "[dnscrypt-proxy 2.1.18 example configuration](https://github.com/DNSCrypt/dnscrypt-proxy/blob/2.1.18/dnscrypt-proxy/example-dnscrypt-proxy.toml)"
  - "[DNSCrypt prebuilt blocklist (domains/mybase.txt)](https://download.dnscrypt.info/blocklists/domains/mybase.txt)"
source_retrieved: 2026-10-14
related:
  - "[[arch-dnscrypt-proxy]]"
  - "[[dnscrypt-proxy-tor]]"
  - "[[Quadlet]]"
  - "[[podlet-compose-to-quadlet]]"
  - "[[podman-registries]]"
  - "[[container-registries]]"
  - "[[searxng-tor]]"
  - "[[dnscrypt-proxy-tor]]"
  - "[[tor]]"
  - "[[NetworkManager]]"
  - "[[DNS-over-HTTPS]]"
  - "[[systemd-exec-hardening]]"
  - "[[Home]]"
  - "[[Vault Conventions]]"
cssclasses:
  - nota-longa
  - wide-table
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Write a vault note on running dnscrypt-proxy under Podman/Quadlet for a single host, verified end-to-end"
ai-review: pending
---

# dnscrypt-proxy in Podman — Encrypted DNS for Host and Containers

> [!summary] One-paragraph answer
> Pull `docker.io/klutchell/dnscrypt-proxy` — a `FROM scratch` image that runs as nonroot
> **uid/gid 65532** and serves on an internal port (`:5053` by default) — and run it as a
> **rootless Quadlet** container. Three keys make it work on a single host: `Sysctl=
> net.ipv4.ip_unprivileged_port_start=0` so the nonroot process can bind **`0.0.0.0:53`**
> inside its own netns; `UserNS=keep-id:uid=65532,gid=65532` so a host-owned
> **`~/.config/dnscrypt-proxy`** mounted **rw** is writable and its cache files come back
> owned by you; and **network-scoped DNS** (`[Network] DNS=<resolver-ip>`) so every other
> container on that network resolves through it automatically — aardvark-dns keeps handling
> container names and forwards everything else to the resolver. Host applications reach the
> same resolver over a published `127.0.0.1:53`, which rootless Podman needs one host sysctl
> to hold. Ad-blocking is the `[blocked_names]` layer plus `enable_hot_reload = true`, fed by
> the packaged `generate-domains-blocklist` or the upstream prebuilt list.

> [!note] Where this sits next to [[arch-dnscrypt-proxy]]
> [[arch-dnscrypt-proxy]] is the **native** install (`pacman -S dnscrypt-proxy`, socket vs
> service mode, the systemd sandbox drop-in, NetworkManager). This note is the **container**
> alternative: a pinned, `FROM scratch` engine with no `/etc` footprint and its own rw config
> dir. They are mutually exclusive on one host — both want port 53. Everything about which
> resolver to pick and the `nmcli` hand-off is deliberately *not* repeated here; follow the
> cross-links.

> [!caution] Status of this note
> The container mechanics below were **verified live on host `bacon`** (Podman 6.1.3): the
> nonroot bind on `:53` with the sysctl, the `keep-id` rw config dir, network-scoped DNS
> resolution through `aardvark-dns`, and a `--read-only --cap-drop=all` run. What was **not**
> executed is the host-port publish and the NetworkManager switchover, because this host
> already runs the native resolver on `127.0.0.1:53`. Treat §8 as `draft`.

## Context

You want encrypted, ad-blocked DNS, and you want it as a **container**: version-pinned, no
`/etc` files, sandboxed by an image that has no shell and runs nonroot, and reproducible
from a unit file. On a single host the container also has to be the resolver for *two*
audiences — your other containers and your desktop applications — which is where most
recipes stop early.

The friction is entirely in three places:

- **Port 53.** The image serves on `0.0.0.0:5053`; `resolv.conf` and aardvark-dns both speak
  port 53. The listener has to move to 53 *inside* the container, and a nonroot process
  cannot bind a low port without help.
- **The rw config dir.** The image is nonroot, so a bind mount owned by your host user is
  read-only to it — until the uid mapping lines up.
- **Two DNS paths.** Other containers want the resolver as their nameserver; the host wants a
  loopback listener. They are configured by different mechanisms.

Reference host state at time of writing (Arch, Podman 6.1.3, cgroup v2): the **native**
`dnscrypt-proxy.service` is active and holds `127.0.0.1:53`; `/etc/resolv.conf` is
`# Generated by NetworkManager` → `nameserver 127.0.0.1`; user lingering is already on. That
is the coexistence problem §8 has to solve.

## Details

### 1. The image (and why there is no official client image)

`DNSCrypt/dnscrypt-server-docker` is the **server** — do not reach for it. For the *client*
the de-facto multiarch image is `docker.io/klutchell/dnscrypt-proxy`. Read its Dockerfile and
the important properties fall out:

| Property | Value | Consequence |
|---|---|---|
| Base / contents | `FROM scratch`, one static binary + `dnsprobe` | no shell, no package manager, nothing to patch |
| User | `USER 65532` (`nonroot:nonroot`) | everything must be writable by 65532 |
| Config mount | `/config` | shadow the baked-in config with your own dir |
| Listen (baked-in) | `0.0.0.0:5053` | **change it to 53** in your config |
| `ENTRYPOINT` / `CMD` | `dnscrypt-proxy` / `-config /config/dnscrypt-proxy.toml` | config file must exist at that path |
| Health tool | `/usr/local/bin/dnsprobe <name> <ip:port>` | exec-form healthcheck, no shell needed |

Because the image is `scratch`, an empty bind mount over `/config` hides the baked
`dnscrypt-proxy.toml` and the container exits at once. **You must supply the config file** —
see §3.

> [!tip] `dnsprobe` is the whole healthcheck story
> `dnsprobe` queries the nameserver in argument 2 and exits non-zero on a network error, an
> error reply (e.g. `NXDOMAIN`) or an empty answer list. That makes it a perfect
> `HealthCmd=` — no `sh -c`, no `dig` install.

### 2. Architecture

One user-defined network, one resolver container, and however many consumers you like:

```
dnscrypt.network  (10.89.0.0/24, gateway 10.89.0.1, DNS=10.89.0.2)
├── dnscrypt-proxy   IP=10.89.0.2   listens 0.0.0.0:53   → upstream DoH/DNSCrypt over the podman bridge
├── consumer-a       (aardvark-dns forwards non-container names to 10.89.0.2:53)
└── consumer-b       …

host loopback:  127.0.0.1:53  ← published from the container for desktop apps
```

The key fact is how container DNS composes, straight from `podman-network-create(1)`: on a
network whose `dns_enabled` is true, the container's `/etc/resolv.conf` points **only** at
aardvark-dns, and *"aardvark-dns then forwards to the supplied ipaddr for all non-container
name queries."* So you never point a consumer at the resolver directly — you put the
resolver's address on the **network**, and aardvark keeps doing container-name lookups while
deferring everything else to dnscrypt-proxy.

> [!important] aardvark forwards on port 53
> The forward target is `ipaddr:53`. That is *why* the container must listen on `0.0.0.0:53`
> and not on the image's default `5053` — a static IP alone is not enough.

### 3. The config dir, mounted rw

The user asked for configs under `~/.config` mounted read-write. That is the right call: the
image writes its resolver-list cache back into `/config`, so a read-only mount spams warnings
(see the gotcha in §11).

```bash
mkdir -p ~/.config/dnscrypt-proxy
$EDITOR ~/.config/dnscrypt-proxy/dnscrypt-proxy.toml     # §4
: > ~/.config/dnscrypt-proxy/blocked-names.txt           # §5 fills this
```

The image's own rule is *"files must be readable by world, or owned by `nonroot:nonroot`
(65532:65532)"*. `UserNS=keep-id:uid=65532,gid=65532` sidesteps that entirely: it maps **your**
host uid onto 65532 inside, so your `0600`-ish files are 65532's, and anything the container
creates is owned by you on the host. Verified — with `keep-id` the cache file lands as
`joaov:joaov`; without it, `Couldn't write cache file [/config/public-resolvers.md]: …
permission denied`.

### 4. A minimal `dnscrypt-proxy.toml`

```toml
# ~/.config/dnscrypt-proxy/dnscrypt-proxy.toml

## Listen on 53 inside the container (image default is 5053). The host-published port and the
## network-scoped DNS both assume 53.
listen_addresses = ['0.0.0.0:53']
timeout = 5000

## Server selection. Leaving server_names empty lets the require_* filters choose. An
## ad-blocking resolver is REJECTED unless require_nofilter = false — see [[arch-dnscrypt-proxy]] §3.
server_names = []                 # or: ['adguard-dns'] to pin a filtering resolver
require_dnssec = false
require_nolog = true
require_nofilter = false

ipv4_servers = true
ipv6_servers = false              # leave false without working IPv6
dnscrypt_servers = true
doh_servers = true

## Bootstrap: only used to fetch the initial resolver list; never for user queries.
bootstrap_resolvers = ['9.9.9.11:53', '8.8.8.8:53']
ignore_system_dns = true
netprobe_timeout = 60
cache = true

## How a blocked query is answered: 'hinfo' (default), 'refused', or 'a:0.0.0.0,aaaa::'.
## These are GLOBAL keys — keep them above the [section] headers.
blocked_query_response = 'hinfo'
reject_ttl = 10
## Pick up edits to blocked-names.txt without a restart (default is false).
enable_hot_reload = true

## Ad-blocking, layer A: the auditable local list.
[blocked_names]
blocked_names_file = '/config/blocked-names.txt'
# log_file = '/config/blocked-names.log'   # set to attribute blocks to your own rules

## Remote resolver list; the cache files are written into /config (needs the rw mount).
[sources.public-resolvers]
urls = [
  'https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md',
  'https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md',
]
cache_file = 'public-resolvers.md'
minisign_key = 'RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3'
refresh_delay = 73
prefix = ''
```

Validate it before touching systemd — the image has no shell, but it does have the binary:

```bash
podman run --rm -v ~/.config/dnscrypt-proxy:/config:Z \
  docker.io/klutchell/dnscrypt-proxy -check -config /config/dnscrypt-proxy.toml
# -> Configuration successfully checked
```

### 5. Ad-blocking, the standard way

Two independent layers, same as the native note; here they are the container equivalents.

**Layer A — local, auditable blocklist.** Point `[blocked_names] blocked_names_file` at a
file in the rw config dir, then fill it with the packaged helper (Arch package
`dnscrypt-proxy`, or run it in a Python container), or with the upstream prebuilt list:

```bash
# Upstream prebuilt list — zero dependencies, one URL.
curl -fsSL https://download.dnscrypt.info/blocklists/domains/mybase.txt \
  -o ~/.config/dnscrypt-proxy/blocked-names.txt

# or the packaged builder (allowlist / local additions / time rules):
#   see [[arch-dnscrypt-proxy]] §4 for generate-domains-blocklist flags and files
```

Keep it fresh with a **user** timer; `enable_hot_reload = true` makes the rewrite take effect
without restarting the unit:

```bash
mkdir -p ~/.config/systemd/user
cat > ~/.config/systemd/user/dnscrypt-blocklist.service <<'EOF'
[Unit]
Description=Refresh the dnscrypt-proxy blocklist

[Service]
Type=oneshot
ExecStart=/usr/bin/curl -fsSL -o %h/.config/dnscrypt-proxy/blocked-names.new \
  https://download.dnscrypt.info/blocklists/domains/mybase.txt
ExecStart=/usr/bin/mv -f %h/.config/dnscrypt-proxy/blocked-names.new \
  %h/.config/dnscrypt-proxy/blocked-names.txt
EOF

cat > ~/.config/systemd/user/dnscrypt-blocklist.timer <<'EOF'
[Unit]
Description=Daily dnscrypt-proxy blocklist refresh

[Timer]
OnCalendar=daily
Persistent=true
RandomizedDelaySec=1h

[Install]
WantedBy=timers.target
EOF

systemctl --user daemon-reload
systemctl --user enable --now dnscrypt-blocklist.timer
```

Writing to `.new` then `mv` means the daemon never reads a half-written list; hot reload
notices the rename.

**Layer B — a filtering remote resolver.** Set `require_nofilter = false` and/or pin
`server_names = ['adguard-dns']`. The local list is the auditable floor; the filtering
resolver catches first-party trackers a public feed does not know about. Details and the
resolver short-name table are in [[arch-dnscrypt-proxy]] §3, not repeated here.

### 6. The Quadlet units

Generate a first draft with `podlet`, then read and refine it (podlet is a starter, not a
validator — see [[podlet-compose-to-quadlet]]):

```bash
mkdir -p ~/.config/containers/systemd

podlet --install --description "dnscrypt-proxy — encrypted DNS + ad-blocking (rootless)" \
  podman run \
  --name dnscrypt-proxy \
  --network dnscrypt.network --ip 10.89.0.2 \
  --userns keep-id:uid=65532,gid=65532 \
  --sysctl net.ipv4.ip_unprivileged_port_start=0 \
  --publish 127.0.0.1:53:53/tcp --publish 127.0.0.1:53:53/udp \
  --volume "$HOME/.config/dnscrypt-proxy:/config:Z" \
  --read-only --read-only-tmpfs=true \
  --security-opt no-new-privileges --cap-drop all \
  --health-cmd '["/usr/local/bin/dnsprobe","example.com","127.0.0.1:53"]' \
  --health-interval 30s --health-timeout 3s --health-retries 3 --health-start-period 30s \
  --restart always \
  docker.io/klutchell/dnscrypt-proxy
```

podlet emits a `# FileName=dnscrypt-proxy` marker (consumed by `podman quadlet install`), the
`[Container]` keys, `[Service] Restart=always` and `[Install] WantedBy=default.target`. Write
both units by hand for full control.

`~/.config/containers/systemd/dnscrypt.network` — the network carries the resolver:

```ini
[Network]
NetworkName=dnscrypt
Subnet=10.89.0.0/24
Gateway=10.89.0.1
# Network-scoped resolver: aardvark-dns forwards every non-container name to this address :53.
DNS=10.89.0.2
```

`~/.config/containers/systemd/dnscrypt-proxy.container`:

```ini
[Unit]
Description=dnscrypt-proxy — encrypted DNS + ad-blocking (rootless)

[Container]
ContainerName=dnscrypt-proxy
Image=docker.io/klutchell/dnscrypt-proxy
Network=dnscrypt.network
IP=10.89.0.2

# Image runs as uid/gid 65532. keep-id maps YOUR host uid to 65532 inside, so the rw config
# dir is writable and cache files come back owned by you.
UserNS=keep-id:uid=65532,gid=65532
# Let the nonroot process bind :53 in its own netns. Without this: "bind: permission denied".
Sysctl=net.ipv4.ip_unprivileged_port_start=0

# Host applications reach the resolver on loopback :53 (needs one host sysctl — see §8).
PublishPort=127.0.0.1:53:53/tcp
PublishPort=127.0.0.1:53:53/udp

# Replace USER with your login. :Z is an SELinux relabel, inert on Arch/AppArmor.
Volume=/home/USER/.config/dnscrypt-proxy:/config:Z

# Hardening: no writable rootfs (ReadOnlyTmpfs defaults true, so /tmp stays rw), no caps,
# no privilege gain. All three were verified to leave the proxy fully working.
ReadOnly=true
DropCapability=all
NoNewPrivileges=true

HealthCmd=["/usr/local/bin/dnsprobe","example.com","127.0.0.1:53"]
HealthInterval=30s
HealthTimeout=3s
HealthRetries=3
HealthStartPeriod=30s
Notify=healthy

[Service]
Restart=always

[Install]
WantedBy=default.target
```

Bring it up:

```bash
systemctl --user daemon-reload
systemctl --user start dnscrypt-proxy.service
systemctl --user status dnscrypt-proxy.service
sudo loginctl enable-linger "$USER"        # already enabled on bacon; needed for boot-without-login
```

> [!tip] Extend, don't rewrite — Quadlet drop-ins
> To change one thing (say, a second `DNS=` for the twelve-factor case, or a longer
> `TimeoutStartSec`), add `~/.config/containers/systemd/dnscrypt-proxy.container.d/10-foo.conf`
> instead of editing the base file. Same `[Section]` format, merged in alphabetical order, the
> same way `systemctl edit` works for units. `daemon-reload` after any change.

### 7. Container consumption

With the network carrying `DNS=10.89.0.2`, every container you attach inherits the resolver —
nothing per-container:

```bash
podman run --rm --network dnscrypt.network docker.io/library/alpine:latest cat /etc/resolv.conf
# search dns.podman
# nameserver 10.89.0.1      <- aardvark-dns, which forwards non-container names to .2:53
# options edns0 trust-ad

podman run --rm --network dnscrypt.network docker.io/library/alpine:latest nslookup example.com
# resolves, served by dnscrypt-proxy, not the host
```

If you would rather scope it per container instead of per network, drop `DNS=` from the
network and set it on each consumer (`[Container] DNS=10.89.0.2`, i.e. `podman run --dns
10.89.0.2`). The trade-off: network-wide is zero-maintenance; per-container is explicit and
avoids the resolver itself inheriting a `resolv.conf` that points back at it.

> [!note] The resolver container's own `resolv.conf` points at itself
> That is harmless here: `ignore_system_dns = true` plus `bootstrap_resolvers` means
> dnscrypt-proxy resolves its resolver-list hostnames through the bootstrap IPs, never through
> its own listener. If you ever set `ignore_system_dns = false`, give the resolver container an
> explicit `DNS=9.9.9.11` to break the loop.

### 8. Host applications — the port sysctl and NetworkManager

Desktop apps talk to `127.0.0.1:53`, which the container publishes. Rootless Podman binds
that host port as your user, so a privileged port needs one sysctl:

```bash
# The error you get without it:
#   rootlessport cannot expose privileged port 53, you can add
#   'net.ipv4.ip_unprivileged_port_start=53' to /etc/sysctl.conf
sudo sysctl -w net.ipv4.ip_unprivileged_port_start=53          # immediate, non-persistent

# persistent (rollback: delete the file, `sudo sysctl --system`)
echo 'net.ipv4.ip_unprivileged_port_start=53' | \
  sudo tee /etc/sysctl.d/50-dnscrypt-unprivileged-ports.conf
```

> [!danger] Stop the native resolver first — one port 53 per host
> On `bacon` the native `dnscrypt-proxy.service` already holds `127.0.0.1:53`. Publishing the
> container port with it running fails (address in use). Choose one:
>
> ```bash
> # hand DNS over to the container
> sudo systemctl disable --now dnscrypt-proxy.service dnscrypt-proxy.socket
> ```
>
> Do **not** run the native daemon and the container publish at the same time. The same rule
> applies to `systemd-resolved` and to a host-bound Tor DNS.

Then point NetworkManager at loopback. The connection-profile keys, the `dns-priority -50`
leak guard and the `systemd-resolved` caveat are in [[arch-dnscrypt-proxy]] §7 — follow that;
nothing about them changes when the resolver is containerized.

### 9. Rootful alternative

If you would rather not set the host sysctl, run the same unit rootful — the system manager
may bind port 53 directly. A rootful container root maps to the host *root*, so a rw config
dir needs different ownership:

```bash
sudo mkdir -p /etc/containers/systemd /etc/dnscrypt-proxy
sudo chown 65532:65532 /etc/dnscrypt-proxy         # image uid; or make it world-writable
# move the units to /etc/containers/systemd/, then:
sudo systemctl daemon-reload
sudo systemctl start dnscrypt-proxy.service
# rootful [Install] uses: WantedBy=multi-user.target
```

You can then drop `PublishPort=` entirely for container-only use, or keep it on `127.0.0.1:53`
for host apps (no sysctl needed as root). `UserNS=keep-id` is meaningless rootful; use
ownership instead.

## Gotchas

> [!danger] Both resolvers want port 53
> The native daemon, the container's host publish, `systemd-resolved`, and a host-bound Tor
> DNS all contend for it. Exactly one may hold `127.0.0.1:53`. `ss -lpn 'sport = :domain'`
> tells you who does.

> [!warning] Without the sysctl, the nonroot listener cannot bind 53
> Verified failure: `[FATAL] listen udp4 0.0.0.0:53: bind: permission denied` (exit 255). The
> `Sysctl=net.ipv4.ip_unprivileged_port_start=0` line is what fixes it — no capability needed.

> [!warning] Without `keep-id`, the rw mount is a lie
> The image is uid 65532; a bind mount owned by your host uid is not writable by it. Verified:
> `Couldn't write cache file [/config/public-resolvers.md]: … permission denied`. Add
> `UserNS=keep-id:uid=65532,gid=65532`, or `chown 65532` the dir.

> [!warning] An empty `/config` mount hides the baked config
> The image ships `/config/dnscrypt-proxy.toml` and `ENTRYPOINT` runs
> `dnscrypt-proxy -config /config/dnscrypt-proxy.toml`. Mount a directory over it without that
> file and the container exits immediately. Always provide the file (§3/§4).

> [!caution] aardvark forwards only to port 53
> If you leave `listen_addresses = ['0.0.0.0:5053']`, network-scoped DNS silently fails: the
> consumer's `resolv.conf` points at aardvark, which forwards to `ipaddr:53` where nothing
> listens. Move the listener to 53.

> [!warning] Blocked queries do not return `NXDOMAIN`
> `blocked_query_response` defaults to `hinfo` ("some responses will be lies"). A `dig`/`nslookup`
> test that expects `NXDOMAIN` for a locally-blocked name will "fail" against the default. The
> definitive proof is `[blocked_names] log_file`, or switch to `'refused'` /
> `'a:0.0.0.0,aaaa::'` and test the option you actually chose.

> [!warning] Updating the blocklist does nothing by itself
> `enable_hot_reload = false` is the default. A timer that rewrites `blocked-names.txt` leaves
> the running daemon on the old rules until a restart — silently. Set `enable_hot_reload = true`.

> [!caution] Quadlet services are transient — `systemctl enable` fails
> Put `[Install] WantedBy=default.target` in the unit (as above). `systemctl --user enable
> dnscrypt-proxy.service` errors with "transient or generated"; that is expected. For
> boot-without-login, `loginctl enable-linger`. Editing `[Install]` also needs `daemon-reload`.

> [!warning] Rootless Quadlet ignores `User=`/`DynamicUser=`
> Quadlet will not run a unit as another user via the systemd `[Service]` keys. Rootless means
> the user unit search path plus lingering; the in-container user is set with the image or
> `User=`, not the unit's `[Service] User=`.

> [!warning] First start can exceed systemd's 90 s start timeout
> The container pulls the image and fetches the resolver list on first boot. Pre-pull, or set
> `[Service] TimeoutStartSec=900`. If the unit "is not found", the generator rejected the file —
> run `/usr/lib/podman/quadlet -dryrun -user` (see [[Quadlet]]).

> [!note] `:Z` is inert on Arch
> Copied from SELinux distros; Arch runs AppArmor by default. Harmless to keep, not required.

## Verification

The checks below were run on `bacon`; each has an expected reading.

```bash
# 1. The container is up and bound to 53 INSIDE (proof the sysctl worked)
podman logs dnscrypt-proxy 2>&1 | grep -E 'listening|FATAL'
#   [NOTICE] Now listening to 0.0.0.0:53 [UDP]
#   [NOTICE] Now listening to 0.0.0.0:53 [TCP]
#   no FATAL

# 2. It actually answers, using the image's own probe (no shell required)
podman exec dnscrypt-proxy /usr/local/bin/dnsprobe example.com 127.0.0.1:53
#   prints one or more A records and exits 0

# 3. The rw config dir really is writable by the nonroot container — files come back yours
ls -l ~/.config/dnscrypt-proxy/public-resolvers.md
#   owner is YOUR user, not 65532

# 4. Blocking is active (default hinfo -> no address for a blocked name)
podman run --rm --network dnscrypt.network docker.io/library/alpine:latest \
  nslookup pagead2.googlesyndication.com
#   no address returned; add [blocked_names] log_file for a definitive line

# 5. Containers resolve through it automatically
podman run --rm --network dnscrypt.network docker.io/library/alpine:latest \
  sh -c 'cat /etc/resolv.conf; nslookup example.com'
#   nameserver 10.89.0.1 (aardvark); example.com resolves

# 6. After the host publish + NM hand-off: the desktop uses it, and nothing leaks
cat /etc/resolv.conf                       # nameserver 127.0.0.1, still "Generated by NetworkManager"
dig +short @127.0.0.1 example.com          # resolves through the container
sudo tcpdump -ni any port 53 and not host 127.0.0.1     # no plaintext leak
```

Negative controls, run once to prove the two keys are load-bearing (then delete the throwaway
container): same image **without** `--sysctl net.ipv4.ip_unprivileged_port_start=0` →
`bind: permission denied`; **without** `--userns keep-id:uid=65532,gid=65532` →
`Couldn't write cache file … permission denied`.

## Related

- [[arch-dnscrypt-proxy]] — the native install; resolver choice, `require_nofilter`, the
  `generate-domains-blocklist` helper, and the NetworkManager keys referenced from §5 and §8
- [[dnscrypt-proxy-tor]] — the same container, routed through Tor: `force_tcp` + `proxy`,
  a self-built image, and the collision rules against the searxng stack
- [[Quadlet]] — the `[Container]` key reference, drop-ins, `[Install]`, and generator debugging
- [[podlet-compose-to-quadlet]] — how `podlet` generates these units, and the three patterns
  for several containers sharing one container
- [[podman-registries]] · [[container-registries]] — making the fully-qualified image name resolve
- [[searxng-tor]] — the other container that wants DNS; do not let two resolvers claim port 53
- [[tor]] — a SOCKS5 sidecar; `force_tcp` + `proxy` in the config routes dnscrypt through it
- [[NetworkManager]] — connection profiles in depth
- [[DNS-over-HTTPS]] — protocol and stamp background
- [[systemd-exec-hardening]] — the general sandbox vocabulary
- [[Vault Conventions]] — the schema this note follows

## Sources

- [klutchell/dnscrypt-proxy README](https://github.com/klutchell/dnscrypt-proxy) — usage,
  `-p 53:5053`, the "world-readable / owned by 65532" config rule, and `dnsprobe`
- [klutchell/dnscrypt-proxy Dockerfile](https://github.com/klutchell/dnscrypt-proxy/blob/main/Dockerfile) —
  `FROM scratch`, `USER 65532`, `/config`, `ENTRYPOINT dnscrypt-proxy`, `CMD -config …`
- [klutchell/dnscrypt-proxy `config/dnscrypt-proxy.toml`](https://github.com/klutchell/dnscrypt-proxy/blob/main/config/dnscrypt-proxy.toml) —
  the baked-in `listen_addresses = ['0.0.0.0:5053']` and the default key set
- [podman-systemd.unit(5)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) —
  `[Container]` keys (`DNS`, `IP`, `UserNS`, `Sysctl`, `HealthCmd`, `ReadOnly`), drop-ins,
  `[Install]`, transient-unit and rootless-`User=` rules
- [podman-network.unit(5)](https://docs.podman.io/en/latest/markdown/podman-network.unit.5.html) —
  `[Network]` keys, including `DNS=`
- [podman-network-create(1)](https://docs.podman.io/en/latest/markdown/podman-network-create.1.html) —
  the aardvark-dns forwarding contract quoted in §2
- [podman-run(1)](https://docs.podman.io/en/latest/markdown/podman-run.1.html) — `--dns`,
  `--userns`, `--sysctl`
- [dnscrypt-proxy 2.1.18 example configuration](https://github.com/DNSCrypt/dnscrypt-proxy/blob/2.1.18/dnscrypt-proxy/example-dnscrypt-proxy.toml) —
  `[blocked_names]`, `blocked_query_response`, `enable_hot_reload`, `[sources]`
- [DNSCrypt prebuilt blocklist `domains/mybase.txt`](https://download.dnscrypt.info/blocklists/domains/mybase.txt) —
  the zero-dependency blocklist source used in §5

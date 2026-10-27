---
title: "Tor on Arch Linux — Client, ControlPort, Bridges and Relays"
aliases:
  - Tor
  - arch tor
  - tor.service
  - onion proxy
  - Tor relay on Arch
description: >-
  Installing and running the Tor daemon on Arch Linux: the SOCKS client and why `socks5h`
  matters, ControlPort authentication for nyx, Tor DNS and transparent-proxy caveats, bridges
  and relays on top of the shipped hardened `tor.service`, pacman's XferCommand over Tor, and
  routing a containerized SearXNG's engine requests through the same proxy.
tags:
  - arch-linux
  - linux
  - tor
  - anonymity
  - networking
  - privacy
  - security
  - dns
  - systemd
  - sandboxing
  - containers
  - podman
type: runbook
status: draft
created: 2026-10-11
updated: 2026-10-12
last_reviewed: 2026-10-11
review_after: 2027-04-11
language: en
audience: sysadmin
scope: >-
  The Tor daemon on a single Arch host: client proxy, ControlPort, DNS, bridges, relays, the
  systemd sandbox, and pointing a containerized SearXNG at it. Tor Browser is only pointed at,
  not documented.
platform:
  - arch-linux
  - systemd
keywords:
  - tor
  - torrc
  - tor.service
  - SOCKSPort
  - ControlPort
  - CookieAuthentication
  - HashedControlPassword
  - nyx
  - torsocks
  - torify
  - obfs4proxy
  - ORPort
  - ExitRelay
  - check.torproject.org
  - searxng
  - using_tor_proxy
  - image_proxy
  - socks5h
  - host.containers.internal
sources:
  - "[ArchWiki: Tor](https://wiki.archlinux.org/title/Tor)"
  - "[tor(1) — Arch manual pages](https://man.archlinux.org/man/tor.1)"
  - "[Arch package: tor 0.4.9.14-1](https://archlinux.org/packages/extra/x86_64/tor/)"
  - "[Tor Project: Middle/Guard relay — Arch Linux](https://community.torproject.org/relay/setup/guard/archlinux/)"
  - "[Tor Project: Bridge — Arch Linux](https://community.torproject.org/relay/setup/bridge/archlinux/)"
  - "[Tor Control Protocol (protocol outline)](https://spec.torproject.org/control-spec/protocol-outline.html)"
  - "[DevelopNSolve: How to Install Tor on Arch Linux](https://www.developnsolve.com/linux/how-to-install-tor-in-arch-linux)"
  - "[SearXNG docs: outgoing: settings](https://docs.searxng.org/admin/settings/settings_outgoing.html)"
  - "[SearXNG docs: Installation with Docker](https://docs.searxng.org/admin/installation-docker.html)"
  - "[SearXNG source: searx/network/network.py](https://github.com/searxng/searxng/blob/master/searx/network/network.py)"
source_retrieved: 2026-10-11
related:
  - "[[Home]]"
  - "[[Vault Conventions]]"
  - "[[arch-dnscrypt-proxy]]"
  - "[[Network and Browser Privacy]]"
  - "[[Firewall Configuration]]"
  - "[[SSH Hardening]]"
  - "[[podman-registries]]"
  - "[[podlet-compose-to-quadlet]]"
  - "[[searxng-tor]]"
cssclasses:
  - nota-longa
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document Tor setup on Arch Linux"
ai-review: pending
---

# Tor on Arch Linux — Client, ControlPort, Bridges and Relays

> [!summary] One-paragraph answer
> Pick the package that matches the job and nothing else. `torbrowser-launcher` is the only
> supported way to *browse* anonymously, and it ships its **own** Tor — you do not need
> `tor.service` for it. The `tor` package is the daemon you configure by hand, and on Arch it
> already ships a *sandboxed* `tor.service`, so extend it with drop-ins instead of rewriting
> it. A client is one line of application config — SOCKS5 on `127.0.0.1:9050`, and always the
> `socks5h` variant so DNS is resolved at the exit node rather than leaking locally. Enable
> `ControlPort` only behind a cookie or password because anything that reaches it can
> reconfigure your node.

> [!caution] Status of this note
> Every command and config key below was read from primary sources (ArchWiki, `tor(1)`, the
> Arch package, the Tor Project relay guides). The systemd unit shape was cross-checked
> against the Arch commit that introduced it. **The procedure has not been executed on a live
> host for this note**, so it is `draft`; verify with `systemctl cat tor.service` before
> relying on a specific directive.

## Context

You are on Arch and want one of:

- a local SOCKS proxy so specific tools (curl, git, IRC, a browser profile) exit through Tor;
- a monitoring/control surface for the node (nyx, a script driving the control protocol);
- to contribute back to the network as a bridge or relay;
- to push package updates through Tor.

These are different goals with different risk profiles. Client use is safe and easy; bridges
are moderately involved; exit relays carry real legal weight. Treat them separately.

## Details

### 1. Install only what you need

| Package | Purpose | Repo |
|---|---|---|
| `tor` | the daemon, `tor-resolve`, `tor-gencert`, `torify` | extra |
| `torbrowser-launcher` | downloads and runs Tor Browser (bundled Tor) | extra |
| `nyx` | TUI monitor for a running node | extra |
| `torsocks` | LD_PRELOAD wrapper to force one app through Tor | extra |
| `obfs4proxy` | pluggable transport for bridges | **AUR / build from source** |

```bash
# client only
sudo pacman -S tor

# browsing anonymously (separate from the daemon)
sudo pacman -S torbrowser-launcher
```

> [!note] The Arch `tor` package is current and lean
> At time of writing the repo packages `tor 0.4.9.14-1`, which installs
> `/usr/bin/tor`, `/usr/lib/systemd/system/tor.service`, `/etc/tor/torrc`,
> `/usr/lib/sysusers.d/tor.conf` (creates the `tor` system user) and
> `/usr/lib/tmpfiles.d/tor.conf`. There is no `/etc/tor/torrc-defaults` in the package — the
> built-in defaults are compiled into the binary and the shipped `torrc` is the commented
> sample.

### 2. The shipped `tor.service` is already sandboxed

Do not replace the unit. `systemctl cat tor.service` shows a hardened service along these
lines:

```ini
[Service]
Type=notify
NotifyAccess=all
ExecStartPre=/usr/bin/tor -f /etc/tor/torrc --verify-config
ExecStart=/usr/bin/tor -f /etc/tor/torrc
ExecReload=/bin/kill -HUP ${MAINPID}
KillSignal=SIGINT
TimeoutSec=60
Restart=on-failure
WatchdogSec=1m
LimitNOFILE=32768

# Hardening
PrivateTmp=yes
PrivateDevices=yes
ProtectHome=yes
ProtectSystem=full
ReadOnlyDirectories=/
ReadWriteDirectories=-/var/lib/tor
ReadWriteDirectories=-/var/log/tor
NoNewPrivileges=yes
CapabilityBoundingSet=CAP_SETUID CAP_SETGID CAP_NET_BIND_SERVICE CAP_DAC_READ_SEARCH
```

Three consequences follow:

- `ExecStartPre` runs `--verify-config`, so a syntax error in `torrc` fails the *service*
  with a readable journal message instead of silently killing the daemon after boot.
- The unit does not set `User=`. Tor starts as root and drops to the unprivileged `tor` user
  according to `User` in `torrc`. Confirm with `grep -i '^User' /etc/tor/torrc`.
- `NoNewPrivileges=yes` blocks setuid/contrieved capability gain. That is correct for a
  client, and it is exactly what breaks an `obfs4` bridge that needs to setcap its port
  (§7).

Never edit the packaged unit in place: `pacman` upgrades overwrite it. Use a drop-in:

```bash
sudo mkdir -p /etc/systemd/system/tor.service.d
sudo tee /etc/systemd/system/tor.service.d/limits.conf >/dev/null <<'EOF'
[Service]
LimitNOFILE=65536
EOF
sudo systemctl daemon-reload
```

### 3. Configure the daemon with drop-ins, not a monolith

Tor reads `/etc/tor/torrc`, or `~/.torrc` if that is missing, and supports included
fragments. Turn that on once in the main file:

```
%include /etc/torrc.d/*.conf
```

Then keep per-concern files in `/etc/torrc.d/` — `client.conf`, `control.conf`,
`relay.conf` — and apply changes without a full restart:

```bash
sudo systemctl reload tor.service   # sends SIGHUP; rewrites the config in place
```

`reload` is enough for `torrc` changes; `restart` is only needed for unit-file changes.

### 4. Client: the one line that matters

There is nothing to configure in `torrc` for a default client — Tor opens SOCKS on
`127.0.0.1:9050` on its own. Point your application at it, and **use `socks5h`, never plain
`socks5`**:

```bash
# correct: hostname resolved by the exit node
curl -x socks5h://localhost:9050 -s https://check.torproject.org

# wrong for anonymity: hostname resolved locally, then carried as an IP
curl -x socks5://localhost:9050 -s https://check.torproject.org
```

The `h` is remote DNS resolution. Plain `socks5` asks the *local* resolver first, which
reveals every hostname you visit to your ISP even though the connection itself rides Tor.
Some tools expose this as a "SOCKS5 remote DNS" checkbox; the string form is `socks5h://`.

For a single stubborn application, wrap it instead:

```bash
torsocks wget -qO- https://check.torproject.org | grep -i congratulations
torify curl https://example.com      # convenience alias for the same wrapper
```

> [!warning] `torsocks` is not transparent
> It intercepts libc network calls, so statically linked binaries and anything that bypasses
> libc slip through. Use it for a quick one-off, not as a leak-proof blanket.

### 5. ControlPort: how nyx and scripts talk to the node

`ControlPort` lets another process read circuits and change settings live. It is powerful and
therefore must be authenticated.

```
# /etc/torrc.d/control.conf
ControlPort 9051
CookieAuthentication 1
CookieAuthFile /var/lib/tor/control_auth_cookie
CookieAuthFileGroupReadable 1
DataDirectoryGroupReadable 1
DisableDebuggerAttachment 0    # lets nyx see per-connection detail
```

Then add trusted users to the `tor` group, restart, and check the resulting permissions:

```bash
sudo usermod -aG tor "$USER"
sudo systemctl restart tor.service
stat -c%a /var/lib/tor /var/lib/tor/control_auth_cookie
# 750
# 640
```

For a password instead of (or in addition to) the cookie, hash it without leaking it into
your shell history:

```bash
set +o history
tor --hash-password 'your_password'
set -o history
```

Put the returned hash in `torrc` as `HashedControlPassword <hash>`. If a program needs a
Unix socket rather than a TCP port, use `ControlSocket /var/lib/tor/control_socket` with
`ControlSocketsGroupWritable 1`.

Verify the control surface:

```bash
echo -e 'PROTOCOLINFO\r\n' | nc 127.0.0.1 9051
# 250-PROTOCOLINFO 1
# 250-AUTH METHODS=COOKIE,SAFECOOKIE,HASHEDPASSWORD COOKIEFILE="/var/lib/tor/control_auth_cookie"
# ... 250 OK / 514 Authentication required.
nyx
```

> [!danger] An unauthenticated ControlPort is a local root-equivalent
> Any local process (and any user) that can reach `9051` can reconfigure your node, open
> arbitrary SOCKSPorts, or interrogate circuits. The control protocol's own spec says it must
> not be reachable by untrusted parties. Never bind it to a non-loopback address, and always
> set at least one of `CookieAuthentication` / `HashedControlPassword`.

### 6. Tor DNS, and where it stops being a good idea

Small, contained wins first:

```bash
tor-resolve archlinux.org          # resolve via the Tor network
```

```
# /etc/torrc.d/dns.conf
DNSPort 9053
AutomapHostsOnResolve 1
AutomapHostsSuffixes .exit,.onion
```

`DHCP`-provided resolvers still win while the IP connection itself is proxied, so this is a
deliberate extra step. Tor's DNS answers only A, AAAA and PTR records — MX and NS queries are
never answered. Making it system-wide means flipping `DNSPort` to `53` and pointing
`/etc/resolv.conf` at loopback, usually with a local cache (`dnsmasq`, `unbound`) in front
because Tor DNS is slow.

> [!caution] Only one thing may own port 53
> If you already run [[arch-dnscrypt-proxy]] (or `systemd-resolved`) on `127.0.0.1:53`, a Tor
> `DNSPort 53` collides with it. Pick a resolver strategy per machine; do not stack them.

### 7. Bridges and relays

**Bridge** (helps people in censored networks; not listed in the public directory). You need
a pluggable transport, which is *not* in the official repos:

```
ORPort TODO1
ServerTransportPlugin obfs4 exec /usr/bin/obfs4proxy
ServerTransportListenAddr obfs4 0.0.0.0:TODO2
ExtORPort auto
ContactInfo you@example.invalid
Nickname mybridge
```

If the obfs4 port is below 1024, give the transport the capability and the unit the
headroom:

```bash
sudo setcap cap_net_bind_service=+ep /usr/bin/obfs4proxy
```

Because the shipped unit sets `NoNewPrivileges=yes`, a setcap'd helper cannot gain the
capability. The Tor Project's workaround is to add a drop-in with `NoNewPrivileges=no` for
the bridge case (ticket 18356) — narrow it to this unit only, and be aware you are loosening
the sandbox the distro chose.

**Guard/middle relay** (forwards, never exits — the safe contribution):

```
Nickname      myNiceRelay
ContactInfo   you@example.invalid   # published in the consensus
ORPort        9001
ExitRelay     0
SocksPort     0
Log notice    syslog
DataDirectory /var/lib/tor
User          tor
```

**Exit relay**: every request appears to originate from *your* IP. Read the Tor Project's
legal resources and exit-node guidance before standing one up, serve a `tor-exit-notice.html`,
and keep an abuse mailbox that a human reads. This is a policy decision, not a config one.

After enabling, the milestone to watch for is `Self-testing indicates your ORPort ... is
reachable from the outside`. Without it the relay is not reachable; check firewall/NAT first.
A brand-new relay stays quiet for hours before appearing on Relay Search.

### 8. pacman over Tor (optional)

```
# /etc/pacman.conf
XferCommand = /usr/bin/curl --socks5-hostname localhost:9050 --location --continue-at - --fail --output %o %u
```

You gain: an observer of your link cannot see which packages, versions or how often you
update. You lose: update speed, and you now depend on the Tor network and exit nodes not
blocking mirrors. On a machine directly exposed to the internet, slow security updates are
themselves a risk — think before enabling this.

GPG still protects you: `pacman` only accepts packages signed by your locally signed keys or
by the Arch master keys, so a malicious exit node cannot substitute a package. That guarantee
does **not** extend to non-official repos or the AUR.

### 9. Transparent torification — read the warning first

It is tempting to force *everything* through Tor with `TransPort`/`DNSPort` and an
nftables/iptables redirect:

```
VirtualAddrNetworkIPv4 10.192.0.0/10
AutomapHostsOnResolve 1
TransPort 9040 IsolateClientAddr IsolateClientProtocol IsolateDestAddr IsolateDestPort
DNSPort 5353
```

> [!danger] This is not a substitute for Tails or Whonix
> The ArchWiki's own iptables ruleset carries a "factual accuracy disputed" banner. System-wide
> redirection can produce **Tor-over-Tor** (a client-side Tor on top of the transparent one),
> which the Tor Project calls unsafe. It does nothing against fingerprinting, and anything
> with root can simply disable the firewall. Use it to stop *accidental* leaks from
> misconfigured apps, never as a malware boundary. For a real anonymity-oriented OS, use
> Tails or Whonix instead of hand-rolling one.

### 10. Kernel capabilities (binding low ports without root)

`setcap CAP_NET_BIND_SERVICE=+eip /usr/bin/tor` works until the next `tor` upgrade resets the
binary's attributes. Prefer the systemd route, which survives upgrades:

```ini
# /etc/systemd/system/tor.service.d/netcap.conf
[Service]
CapabilityBoundingSet=
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
AmbientCapabilities=
AmbientCapabilities=CAP_NET_BIND_SERVICE
```

Note that the shipped unit already includes `CAP_NET_BIND_SERVICE` in its bounding set and
starts as root before dropping to `tor`, so for the common relay case this drop-in is
usually unnecessary — verify rather than assume.

### 11. SearXNG in a container — send engine requests through Tor

SearXNG sends every engine request through one HTTP client, so a single `outgoing.proxies`
entry covers all engines. The whole difficulty is *how the container reaches Tor*:
`localhost:9050` inside a container is the container, not the host.

Two placements work.

**A. Tor as a sidecar in the same compose project** (recommended for containerized setups —
self-contained, nothing exposed on the host):

```yaml
# compose.yaml — podman-compose / docker compose
name: searxng

services:
  core:
    image: docker.io/searxng/searxng:latest
    container_name: searxng-core
    restart: unless-stopped
    ports:
      - "127.0.0.1:8080:8080"
    volumes:
      - ./core-config:/etc/searxng          # append :Z on SELinux hosts
    environment:
      - SEARXNG_BASE_URL=http://localhost:8080/
    depends_on:
      - tor

  tor:
    image: docker.io/dockurr/tor:latest     # client-only by default
    container_name: searxng-tor
    restart: unless-stopped
    volumes:
      - tor-data:/var/lib/tor
    # deliberately no `ports:` — SOCKS stays on the compose network

volumes:
  tor-data:
```

SearXNG then reaches Tor at `tor:9050` (the compose service name). `dockurr/tor` is an
Alpine-based image that runs the daemon in plain proxy mode, exposing SOCKSv5 on `9050` (and
an HTTPS proxy on `8118`). Leave it without a `torrc` unless you want a relay, and if you swap
in a different image, confirm it binds `SocksPort 0.0.0.0:9050` inside the container. The
`tor-data` volume persists `/var/lib/tor` — optional for a plain client, required to keep a
relay or onion-service identity.

**B. Reuse the host `tor.service` from §2.** You have to solve container→host addressing:

- Rootless Podman (pasta, the default since 5.0) resolves `host.containers.internal` to the
  host, but a service bound to the host's `127.0.0.1` is not reachable that way by default.
- The blunt instrument that always works is `network_mode: host` on the SearXNG container:
  then `socks5h://127.0.0.1:9050` is correct, at the cost of SearXNG binding ports directly
  on the host.

```yaml
  core:
    # ...
    network_mode: host
```

> [!danger] Never bind Tor's SOCKS port to `0.0.0.0`
> Making host Tor reachable to a container by setting `SocksPort 0.0.0.0:9050` turns the
> machine into an **open Tor proxy** on every interface, including any public one. If you must
> expose it, bind to the specific podman bridge/gateway address and firewall it to the
> container subnet. Fix the addressing, do not bind-all.

The SearXNG side is the `settings.yml` you mount at `/etc/searxng/settings.yml`:

```yaml
use_default_settings: true

server:
  image_proxy: true        # re-host result images; the container template already sets this

outgoing:
  proxies:
    all://:
      - socks5h://tor:9050            # sidecar; or socks5h://127.0.0.1:9050 with network_mode: host
  using_tor_proxy: true
  request_timeout: 10.0
  max_request_timeout: 30.0
  extra_proxy_timeout: 10.0
```

| Setting | Why |
|---|---|
| `proxies: all://:` | matches every engine; list several for round-robin |
| `socks5h://` | hostnames resolved by Tor, not locally |
| `using_tor_proxy: true` | fail-closed: at startup SearXNG fetches `check.torproject.org/api/ip` and refuses to serve unless `IsTor` is true |
| `request_timeout` / `max_request_timeout` | Tor latency — the first request after boot waits for a circuit |
| `extra_proxy_timeout` | adds slack on top of each engine's per-request timeout |
| `server.image_proxy: true` | result images are fetched directly, bypassing Tor, when this is off. The upstream default is off, but the container's `settings.template.yml` sets it on |

> [!important] `using_tor_proxy: true` refuses non-`socks5h` proxies
> SearXNG's check requires every proxy URL to start with `socks5h://`. A `socks5://` entry
> makes the check return false and the client raises
> `ProxyError: Network configuration problem: not using Tor` — surfaced at boot as
> `RuntimeError: Invalid network configuration`. That is the fail-closed behaviour working as
> designed, and it is the usual cause of "enabling `using_tor_proxy` breaks my instance".

If sending *every* engine through Tor is too slow or draws CAPTCHAs, scope it: define a named
network under `outgoing.networks` and reference it from an individual engine with
`network: <name>` instead of using the global `proxies`.

> [!tip] Managing the container pair as systemd units
> The compose layouts in §11 can be run as native systemd services with Quadlet; see
> [[podlet-compose-to-quadlet]] for generating the units and for the three ways several
> containers can share **one** Tor container (shared netns, a pod, or a shared Podman
> network). Sharing the container places services next to Tor — it does not route their
> traffic, so the `socks5h://…:9050` proxy setting here is still required.

## Gotchas

> [!warning] `socks5` vs `socks5h` — the classic leak
> Plain `socks5://` resolves the hostname *locally*. The request rides Tor, the DNS query
> does not. Always `socks5h://`, or explicitly enable remote DNS in the application.

> [!caution] Tor Browser does not use `tor.service`
> `torbrowser-launcher` starts its own Tor and proxies through it. Enabling `tor.service`
> alongside it is redundant and, if you then configure anything to share the port, confusing.
> Run the service only for your *own* tools and relays.

> [!warning] `NoNewPrivileges=yes` breaks setcap'd helpers
> The visible symptom is an obfs4 transport that cannot bind its port, with a permission
> error in the journal despite a correct `setcap`. That is the sandbox doing its job. Apply
> the documented `NoNewPrivileges=no` drop-in only for the bridge and only if you must.

> [!caution] Editing the packaged unit
> `systemctl edit tor.service` (or a file under `/etc/systemd/system/tor.service.d/`) is the
> supported path. `pacman -Syu` overwrites anything you change in
> `/usr/lib/systemd/system/tor.service`. Run `systemctl daemon-reload` after adding a *new*
> unit or drop-in file.

> [!note] Drop-in includes need `.conf` and a reload
> `%include /etc/torrc.d/*.conf` only picks up matching files that already exist, and the
> daemon reads them at SIGHUP. `systemctl reload tor.service` — not a reboot and usually not
> a restart — applies `torrc` changes.

> [!warning] Slower updates over Tor are a security trade-off
> The pacman-over-Tor `XferCommand` buys metadata privacy at the cost of update latency. On a
> directly-exposed host that latency can matter more than the privacy.

> [!warning] `localhost:9050` in a containerized SearXNG
> Inside a container, `localhost` is the container's own loopback. Unless the container uses
> `network_mode: host`, `socks5h://localhost:9050` gives connection refused and SearXNG logs a
> `ProxyError` or dies with `RuntimeError: Invalid network configuration`. Use the sidecar
> service name (`tor:9050`) or `host.containers.internal`.

> [!warning] A published Tor SOCKS port is an open proxy
> Publishing the sidecar (`-p 9050:9050`) or binding host Tor to `0.0.0.0` gives anything that
> can reach the port a proxy into Tor. Keep the sidecar on the compose network and never
> publish `9050`.

> [!note] Every engine through Tor is slower and gets more CAPTCHAs
> Google, DuckDuckGo and others rate-limit or block Tor exits, so expect CAPTCHAs and the odd
> engine failure. Route everything through Tor, or scope it per engine with
> `outgoing.networks` + `network:`, depending on whether privacy or result quality matters more.

## Verification

```bash
# 1. the service is up and bootstrapped
systemctl status tor.service --no-pager
journalctl -u tor.service -b | grep -i 'Bootstrapped 100%'

# 2. it is listening where you expect
ss -tlnp | grep -E ':(9050|9051|9053)\b'

# 3. traffic really exits via Tor (the "Congratulations" page)
curl -x socks5h://localhost:9050 -s https://check.torproject.org | grep -i congratulations

# 4. DNS through Tor, and no local leak on :53
tor-resolve archlinux.org
ss -tup | grep ':53'          # expect only loopback resolvers

# 5. the control surface answers (cookie/password enforced)
echo -e 'PROTOCOLINFO\r\n' | nc 127.0.0.1 9051

# 6. sandbox is applied (expect NoNewPrivileges=yes, ProtectSystem=full)
systemctl show tor.service -p NoNewPrivileges -p ProtectSystem -p CapabilityBoundingSet
systemd-analyze security tor.service --no-pager | tail -3

# 7. containerized SearXNG really exits via Tor
#    curl from a throwaway container on the same compose network (name: searxng → searxng_default)
podman run --rm --network searxng_default docker.io/curlimages/curl:latest \
  -s --socks5-hostname tor:9050 https://check.torproject.org/api/ip
podman logs searxng-core 2>&1 | grep -iE 'Invalid network configuration|ProxyError'   # expect nothing
```

Expected readings, not just commands:

- Step 1: journal ends at `Bootstrapped 100%`; that is the only proof the daemon reached the
  network. A `--verify-config` failure means the service never started, not that Tor is slow.
- Step 3: the page contains "Congratulations. This browser is configured to use Tor." Any
  other body is a proxy misconfiguration.
- Step 4: `ss` shows a resolver on `127.0.0.1`/`::1` only. An external `:53` entry is a leak —
  fix the client, not Tor.
- Step 5: `250 OK` or `514 Authentication required.` is success; a connection *served without*
  authentication is the failure you are looking for.
- Step 7: the JSON shows `"IsTor":true`; if it is `false` or the call fails, SearXNG is
  reaching Tor but not through it — check the proxy host in `settings.yml` first.

## Related

- [[arch-dnscrypt-proxy]] — the other local resolver; do not let both claim port 53
- [[Network and Browser Privacy]] — MAC randomization and Firefox hygiene that complement Tor
- [[Firewall Configuration]] — what may connect in; Tor only governs what goes out
- [[SSH Hardening]] — the transport hardening you may still want alongside Tor
- [[podman-registries]] — Podman image/registry basics behind the containerized SearXNG + Tor sidecar in §11
- [[podlet-compose-to-quadlet]] — turning a Compose sidecar into Quadlet units, and letting several services share one Tor container
- [[Vault Conventions]] — the schema this note follows

## Sources

- [ArchWiki: Tor](https://wiki.archlinux.org/title/Tor) — installation split, SOCKS usage,
  ControlPort/auth methods, DNS, pacman `XferCommand`, relay and transparent-proxy sections
- [tor(1)](https://man.archlinux.org/man/tor.1) — `torrc` file precedence, `SocksPort`,
  `ControlPort`, `Sandbox`, `%include` behaviour
- [Arch package: tor 0.4.9.14-1](https://archlinux.org/packages/extra/x86_64/tor/) — version
  and shipped file list (`tor.service`, `sysusers.d`, `tmpfiles.d`, `/etc/tor/torrc`)
- [Tor Project: Middle/Guard relay — Arch Linux](https://community.torproject.org/relay/setup/guard/archlinux/) —
  the relay `torrc` baseline and `systemctl enable --now tor`
- [Tor Project: Bridge — Arch Linux](https://community.torproject.org/relay/setup/bridge/archlinux/) —
  `obfs4proxy`, `NoNewPrivileges=no` workaround (ticket 18356), obfs4 port reachability
- [Tor Control Protocol, protocol outline](https://spec.torproject.org/control-spec/protocol-outline.html) —
  why the control port must be restricted to trusted parties
- Arch commit history for `tor.service` (PrivateTmp/ProtectSystem/ReadOnlyDirectories/
  NoNewPrivileges block) — the shipped sandbox directives in §2
- [SearXNG docs: `outgoing:` settings](https://docs.searxng.org/admin/settings/settings_outgoing.html) —
  `proxies`, `using_tor_proxy`, and the timeout keys used in §11
- [SearXNG docs: Installation with Docker](https://docs.searxng.org/admin/installation-docker.html) —
  the compose layout and `/etc/searxng` config mount
- [SearXNG source: `searx/network/network.py`](https://github.com/searxng/searxng/blob/master/searx/network/network.py) —
  the `check.torproject.org/api/ip` Tor check and the `socks5h://`-only requirement behind
  `using_tor_proxy: true`
- [DevelopNSolve: How to Install Tor on Arch Linux](https://www.developnsolve.com/linux/how-to-install-tor-in-arch-linux) —
  read as a counter-example: it covers `pacman -S tor` and `systemctl enable`, but never
  mentions `socks5h` remote DNS, the shipped sandbox, or control-port authentication

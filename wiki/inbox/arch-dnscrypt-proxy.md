---
title: "Arch dnscrypt-proxy — Encrypted DNS, Ad-Blocking and systemd Hardening"
aliases:
  - dnscrypt-proxy
  - arch dnscrypt-proxy
  - encrypted DNS on Arch
  - DoH on Arch
  - DNS ad blocking
description: >-
  End-to-end setup of dnscrypt-proxy on Arch Linux: socket-activation versus service mode,
  two independent ad-blocking layers, an additive systemd sandbox drop-in on top of the one
  Arch already ships, and the NetworkManager keys that make the system actually use the local
  resolver instead of the router's.
tags:
  - arch-linux
  - linux
  - dns
  - dns-over-https
  - dnscrypt
  - adblocking
  - systemd
  - sandboxing
  - networkmanager
  - security
  - privacy
  - networking
categories:'networking'
categories: networking
type: runbook
status: draft
created: 2026-09-27
updated: 2026-10-14
last_reviewed: 2026-10-14
review_after: 2026-10-27
language: en
audience: sysadmin
scope: >-
  Single-host dnscrypt-proxy install, hardening and DNS-path integration. Does not cover
  systemd-resolved topologies, DNSSEC validation, or router/firewall configuration.
platform:
  - arch-linux
  - systemd
  - networkmanager
keywords:
  - dnscrypt-proxy
  - DoH
  - DNSCrypt v2
  - socket activation
  - SocketBindDeny
  - SocketBindAllow
  - blocked-names.txt
  - generate-domains-blocklist
  - require_nofilter
  - enable_hot_reload
  - resolv.conf
  - ignore-auto-dns
  - dns-priority
  - systemd-analyze security
sources:
  - "[ArchWiki: dnscrypt-proxy](https://wiki.archlinux.org/title/Dnscrypt-proxy)"
  - "[Arch package PKGBUILD for dnscrypt-proxy 2.1.18](https://gitlab.archlinux.org/archlinux/packaging/packages/dnscrypt-proxy/-/blob/main/PKGBUILD)"
  - "[Arch shipped dnscrypt-proxy.service / .socket](https://gitlab.archlinux.org/archlinux/packaging/packages/dnscrypt-proxy/-/blob/main/dnscrypt-proxy.service)"
  - "[dnscrypt-proxy 2.1.18 example configuration](https://github.com/DNSCrypt/dnscrypt-proxy/blob/2.1.18/dnscrypt-proxy/example-dnscrypt-proxy.toml)"
  - "[upstream systemd resource-control(5) — SocketBindAllow / SocketBindDeny](https://man.archlinux.org/man/systemd.resource-control.5.en)"
  - "[NetworkManager nm-settings-nmcli(5)](https://man.archlinux.org/man/nm-settings-nmcli.5.en)"
  - "[nixCraft: How to install dnscrypt proxy with adblocker on Linux](https://www.cyberciti.biz/faq/how-to-install-dnscrypt-proxy-with-adblocker-on-linux/)"
source_retrieved: 2026-09-27
related:
  - "[[Home]]"
  - "[[Vault Conventions]]"
  - "[[dnscrypt-proxy-tor]]"
  - "[[dnscrypt-proxy-podman]]"
  - "[[systemd-exec-hardening]]"
  - "[[NetworkManager]]"
  - "[[DNS-over-HTTPS]]"
cssclasses:
  - nota-longa
  - wide-table
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document dnscrypt-proxy setup on Arch"
ai-review: pending
---

# Arch dnscrypt-proxy — Encrypted DNS, Ad-Blocking and systemd Hardening

> [!summary] One-paragraph answer
> `sudo pacman -S dnscrypt-proxy`, then pick **exactly one** activation mode. Arch already
> ships a service unit that is sandboxed with `DynamicUser=`, `ProtectSystem=strict`,
> `SystemCallFilter=@system-service` and a `CAP_NET_BIND_SERVICE` bounding set, so the job is
> to *extend* that with a drop-in, not to write one from scratch. Ad-blocking is two
> independent layers: a local blocklist built by the packaged
> `generate-domains-blocklist` helper, and/or a filtering remote resolver — the latter needs
> `require_nofilter = false` or the default filter rejects it. The step most guides skip:
> NetworkManager owns `/etc/resolv.conf` on this machine, so editing that file achieves
> nothing until the connection profile is changed with `ipv4.dns` + `ipv4.ignore-auto-dns`.

> [!caution] Status of this note
> Every config key, unit file and systemd directive below was read from primary sources
> (packaging repo, upstream 2.1.18 example config, `man` pages) and the directives were
> accepted by `systemd-analyze verify` on systemd 262. **The procedure itself has not been
> executed on a live host**, so this note is `draft`. If any command diverges from what is
> written here, note it and update this note rather than working around it.

## Context

You want DNS to stop leaking to the router in cleartext, you want ads blocked, and you want
the daemon sandboxed tighter than the distro default. On Arch the three pieces fight each
other unless you are deliberate about it:

- `dnscrypt-proxy` wants port 53, which needs `CAP_NET_BIND_SERVICE` — and a port 53 squat by
  `systemd-resolved` is the usual reason a fresh install resolves nothing.
- NetworkManager rewrites `/etc/resolv.conf` on every reconnection, so any manual edit is
  reverted within seconds. The DNS path has to be configured in the *connection profile*.
- The Arch unit is already hardened, so a drop-in that re-declares the same directives is
  noise; one that tightens the wrong thing breaks the daemon in ways that look like network
  faults.

Reference host state at time of writing (Arch, systemd 262, NetworkManager 1.58.1):
`/etc/resolv.conf` is `# Generated by NetworkManager` → `nameserver 192.168.0.1`;
`systemd-resolved` is not installed; nothing holds port 53.

## Details

### 1. Install and see exactly what you got

```bash
sudo pacman -S dnscrypt-proxy

# units, binary, config, blocklist helper
pacman -Ql dnscrypt-proxy | grep -E 'systemd|/bin/|utils/'

# what is already holding port 53 (empty output other than the header = free)
ss -lp 'sport = :domain'
```

Arch packages 2.1.18 and ships:

| Path | What |
|---|---|
| `/usr/bin/dnscrypt-proxy` | the daemon |
| `/usr/bin/generate-domains-blocklist` | blocklist builder helper |
| `/usr/share/doc/…`, `/usr/share/licenses/…` | docs |
| `/usr/lib/systemd/system/dnscrypt-proxy.service` | service unit |
| `/usr/lib/systemd/system/dnscrypt-proxy.socket` | socket unit |
| `/etc/dnscrypt-proxy/dnscrypt-proxy.toml` | config (pkgshipped, in `backup=`) |
| `/etc/dnscrypt-proxy/{allowed,blocked}-{ips,names}.txt` | filter rule files |
| `/etc/dnscrypt-proxy/{cloaking,forwarding}-rules.txt`, `captive-portals.txt` | rule files |
| `/usr/share/dnscrypt-proxy/utils/generate-domains-blocklist/` | blocklist sources + allowlist |

> [!important] There is no `dnscrypt-proxy` user in `/etc/passwd`
> The unit uses `DynamicUser=yes`. The account is allocated transiently at start and released
> at stop, and `nss-systemd(8)` resolves it on demand. Consequently the ArchWiki advice to
> `chown dnscrypt-proxy:dnscrypt-proxy /var/cache/dnscrypt-proxy` is **obsolete** — it
> described older packaging with a static user. `CacheDirectory=dnscrypt-proxy` already
> hands the daemon a correctly owned writable directory.

### 2. Pick one activation mode — they are mutually exclusive

| | Service mode | Socket mode |
|---|---|---|
| `listen_addresses` | **must** be set | **must be empty** (`[ ]`) |
| Unit to enable | `dnscrypt-proxy.service` | `dnscrypt-proxy.socket` |
| Port 53 holder | the daemon | systemd |
| `CAP_NET_BIND_SERVICE` | required | not needed |
| Upstream's preference | — | recommended |

Upstream recommends socket activation. Pick one, and disable the other — enabling both gives
you two things fighting over port 53.

**Socket mode** (recommended):

```bash
# /etc/dnscrypt-proxy/dnscrypt-proxy.toml
listen_addresses = [ ]

sudo systemctl disable --now dnscrypt-proxy.service   # if previously enabled
sudo systemctl enable --now dnscrypt-proxy.socket
```

The shipped socket unit listens on `127.0.0.1:53` and `[::1]:53` (TCP + UDP, `NoDelay=true`,
`DeferAcceptSec=1`).

**Service mode** instead:

```bash
listen_addresses = ['127.0.0.1:53', '[::1]:53']

sudo systemctl disable --now dnscrypt-proxy.socket
sudo systemctl enable --now dnscrypt-proxy.service
```

Validate before restarting anything:

```bash
dnscrypt-proxy -check -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml

# which resolvers actually survive your filters
dnscrypt-proxy -list -config /etc/dnscrypt-proxy/dnscrypt-proxy.toml
```

The binary is installed mode 0755, so both run unprivileged. Prefix with `sudo` if they
complain about `/var/cache/dnscrypt-proxy` — that directory belongs to the transient
`DynamicUser` account, which is exactly the kind of ownership error the `DynamicUser` design
is meant to make impossible.

`-check` prints `NOTICE` lines for deprecated keys (`blacklist`, `ip_blacklist`,
`refused_code_in_responses`) and ends with `Configuration successfully checked`. A *clean*
2.1.18 config produces those deprecation notices only if you copied an old file.

### 3. Resolver selection, and the filter that hides every blocker

`/etc/dnscrypt-proxy/dnscrypt-proxy.toml` (global section, not under any `[section]`):

```toml
# Leave empty (the default) to auto-pick the fastest server that satisfies require_*.
# Setting it does NOT disable ad-blocking; it only pins the choice.
server_names = [ 'adguard-dns' ]

# Upstream default is true, which means "only servers that do NOT filter".
# A filtering resolver is rejected unless this is false.
require_nofilter = false

require_dnssec = false
require_nolog = true

ipv4_servers = true
ipv6_servers = false        # leave false unless IPv6 genuinely works
dnscrypt_servers = true
doh_servers = true
odoh_servers = false

cache = true
ignore_system_dns = true
timeout = 5000
```

Verified short names in the upstream `public-resolvers` list, so you do not have to guess:

| Name | Behaviour |
|---|---|
| `adguard-dns` | blocks ads, trackers, phishing, malware |
| `adguard-dns-unfiltered` | same provider, no filtering |
| `mullvad-adblock-doh` | ad-blocking, DoH |
| `mullvad-base-doh` | no filtering |
| `quad9-doh-ip4-port443-filter-ecs-pri` | malicious-domain blocking, DNSSEC |
| `quad9-doh-ip4-port443-nofilter-ecs-pri` | non-filtering Quad9 |
| `cleanbrowsing-security` | malware/phishing, not ads |
| `nextdns` | filtering, profile-dependent |

> [!warning] `server_names` silently disables the `require_*` filters
> The upstream config states it outright: *"the require_\* filters do NOT apply when using
> this setting."* So `require_nofilter = false` in the snippet above is **only** meaningful
> while `server_names` is empty. The moment you pin `server_names = [ 'adguard-dns' ]`, that
> name is used regardless of `require_*` — which is why both routes end up working, and why
> `require_dnssec = true` in guides that also pin `server_names` is decorative.

> [!caution] `adguard-dns` and anonymisation
> The upstream resolver entry for `adguard-dns` carries: *"Warning: This server is
> incompatible with anonymization."* Do not combine it with the `[anonymized_dns]` section
> or with relays.

### 4. Ad-blocking layer A — local blocklist (auditable, resolver stays honest)

This is the layer that keeps working if the upstream resolver changes policy: the rules live
in `/etc`, and you can read exactly what is blocked.

```bash
# Arch ships the source lists; the helper only needs python3
cd /usr/share/dnscrypt-proxy/utils/generate-domains-blocklist

sudo generate-domains-blocklist \
  --config domains-blocklist.conf \
  --allowlist domains-allowlist.txt \
  --time-restricted domains-time-restricted.txt \
  --output-file /etc/dnscrypt-proxy/blocked-names.txt

wc -l /etc/dnscrypt-proxy/blocked-names.txt
head -20 /etc/dnscrypt-proxy/blocked-names.txt
```

`domains-blocklist.conf` lists the remote feeds; the local additions
(`ads.*`, `telemetry.*`, `*.lan`, …) are in `domains-blocklist-local-additions.txt`. Useful
flags: `-i` keep going when a feed fails, `-t <seconds>` per-URL timeout, `-p` progress.
The helper writes plain `one-pattern-per-line` output — the same format the
`blocked-names.txt` file takes — and it uses only the Python standard library, despite
`python-urllib3` being listed as an optdepend.

Wire it up. The keys live in the *named sections*, not at the top level:

```toml
# /etc/dnscrypt-proxy/dnscrypt-proxy.toml

[blocked_names]
blocked_names_file = '/etc/dnscrypt-proxy/blocked-names.txt'
log_file = '/var/log/dnscrypt-proxy/blocked-names.log'

[allowed_names]
allowed_names_file = '/etc/dnscrypt-proxy/allowed-names.txt'

# global: how a blocked query is answered
blocked_query_response = 'hinfo'   # 'refused', or 'a:0.0.0.0,aaaa::'
reject_ttl = 10

# global: pick up file edits without a restart
enable_hot_reload = true
```

Fill `/etc/dnscrypt-proxy/allowed-names.txt` before you go live — the allowlist exists to
undo collateral damage, and a broken login or CDN is the usual first casualty.

Keep it fresh with a timer, not cron, so the reload is an explicit part of the unit:

```bash
sudo tee /etc/systemd/system/dnscrypt-proxy-blocklist.service >/dev/null <<'EOF'
[Unit]
Description=Regenerate the dnscrypt-proxy local blocklist

[Service]
Type=oneshot
WorkingDirectory=/usr/share/dnscrypt-proxy/utils/generate-domains-blocklist
ExecStart=/usr/bin/generate-domains-blocklist -c domains-blocklist.conf -a domains-allowlist.txt -r domains-time-restricted.txt -o /etc/dnscrypt-proxy/blocked-names.new
ExecStart=/usr/bin/mv -f /etc/dnscrypt-proxy/blocked-names.new /etc/dnscrypt-proxy/blocked-names.txt
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
sudo systemctl list-timers dnscrypt-proxy-blocklist.timer
```

> [!warning] `systemctl edit` needs a real terminal
> `systemctl edit` opens `$EDITOR` and aborts outright when stdin is not a tty:
> `Cannot edit units interactively if not on a tty.` That rules out
> `systemctl edit foo.service <<'EOF' … EOF` — the heredoc takes stdin away from the
> terminal and the command fails. Use it interactively with no redirection, or write the
> unit file directly as above. `daemon-reload` is required after adding a *new* unit file
> (not after editing an existing one).

Writing to a `.new` file and renaming keeps the daemon from ever reading a half-written list.
`enable_hot_reload = true` makes the rename take effect on its own; without it you need
`sudo systemctl restart dnscrypt-proxy` in `ExecStartPost=` — and with a *timer*-activated
unit, restarting the proxy would fight the socket unit's laziness.

### 5. Ad-blocking layer B — filtering remote resolver

Already covered in §3: pin a filtering resolver by name. Keep `require_nofilter = false` so
the choice is also expressed as a filter when `server_names` is empty.

The two layers compose, which is what you want: the local blocklist is the auditable floor,
and the filtering resolver catches first-party trackers whose domains are unknown to a public
feed.

> [!warning] Layers compose, so `dig` cannot tell you which layer blocked a name
> A locally blocked domain returns a synthetic response; a domain blocked upstream returns
> `NXDOMAIN`. Enable `[blocked_names] log_file` to attribute blocks to your own rules.

### 6. The systemd sandbox — what is already there, and what to add

`dnscrypt-proxy.service` as shipped by Arch is **already** sandboxed. Do not replace it.

| Shipped directive | Effect |
|---|---|
| `DynamicUser=yes` | transient user, no `/etc/passwd` entry |
| `ProtectSystem=strict` | whole filesystem read-only except `*Directory=` paths |
| `NoNewPrivileges=true` | no privilege gain via setuid |
| `MemoryDenyWriteExecute=true` | no writable+executable mappings |
| `SystemCallFilter=@system-service` | allow-list syscall groups |
| `SystemCallArchitectures=native` | one ABI |
| `CapabilityBoundingSet=CAP_NET_BIND_SERVICE` | only bind-low-port survives |
| `AmbientCapabilities=CAP_NET_BIND_SERVICE` | …and only that one is granted |
| `PrivateDevices=true` | minimal `/dev` |
| `ProtectHome=yes`, `ProtectHostname=yes` | no home, no UTS |
| `ProtectKernel{Tunables,Modules,Logs}` | no `/proc/sys`, `/sys`, kernel log |
| `ProtectControlGroups=yes` | no cgroup writes |
| `LockPersonality`, `RestrictNamespaces`, `RestrictRealtime` | no personality, namespace, RT syscalls |
| `CacheDirectory=`, `StateDirectory=`, `LogsDirectory=`, `RuntimeDirectory=` | the four writable paths |

Because `DynamicUser=` is set, systemd also forces `ProtectSystem=strict`,
`NoNewPrivileges=true`, and `ProtectHome=read-only` / `PrivateTmp=disconnected` if you have
not set them — which is why nobody has to think about them.

Score the baseline, then add the missing layers:

```bash
systemd-analyze security dnscrypt-proxy.service
```

`systemctl edit` writes the drop-in to
`/etc/systemd/system/dnscrypt-proxy.service.d/override.conf` — but only from a real
terminal (see the callout in §4). To write it non-interactively, create the directory and the
file directly:

```bash
sudo mkdir -p /etc/systemd/system/dnscrypt-proxy.service.d
sudo tee /etc/systemd/system/dnscrypt-proxy.service.d/override.conf >/dev/null <<'EOF'
[Service]
# Hide other users' processes. Documented as "generally recommended to run most system
# services with this option set to invisible". Effective because DynamicUser=yes is set —
# root is exempt from this, so without User=/DynamicUser= it would do nothing.
ProtectProc=invisible

# Cannot set the clock, nor use CAP_SYS_TIME / CAP_WAKE_ALARM. Reading time is unaffected,
# so TLS certificate validation for DoH still works.
ProtectClock=yes

# Refuse the setuid/setgid bits. Not implied by anything else above.
RestrictSUIDSGID=yes

# Stock is "AF_INET AF_INET6". AF_UNIX is added back on purpose: glibc NSS lookups for the
# dynamic user (nss-systemd) and cgo resolver paths talk to systemd over a unix socket.
# Drop ", AF_UNIX" if you never need it and want the tighter set.
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# bind(2) allow-list, enforced with cgroup/bind4 + cgroup/bind6 BPF hooks.
# Service mode only — see the callout below.
SocketBindDeny=any
SocketBindAllow=udp:53
SocketBindAllow=tcp:53
EOF
```

Then:

```bash
systemctl restart dnscrypt-proxy.service   # or: systemctl restart dnscrypt-proxy.socket
systemd-analyze security dnscrypt-proxy.service
systemctl show dnscrypt-proxy.service -p ProtectProc -p ProtectClock -p RestrictSUIDSGID
```

Rules the `SocketBind*` pair actually follows, per `systemd.resource-control(5)`:

1. A bind is **allowed** if the address matches any `SocketBindAllow=` entry.
2. Otherwise it is **denied** if it matches any `SocketBindDeny=` entry.
3. Otherwise it is **allowed**.

Plus: the grammar is `[address-family:][transport-protocol:]ip-ports`, e.g. `udp:53`,
`ipv6:10000-65535`; `any` matches everything; lists combine across repeated assignments; an
empty assignment resets the list; 128 entries max; and it applies to `bind(2)` **regardless of
network namespace** — moving to another netns does not escape it.

> [!warning] `SocketBind*` is a no-op in socket-activation mode
> The hooks apply to processes *in the unit's cgroup*. In socket mode systemd itself creates
> the listening sockets, so the daemon never calls `bind(2)` and the restriction protects
> nothing. Apply the pair in **service mode only**. If you enable `[local_doh]`, add
> `SocketBindAllow=tcp:3000` (or whatever port you chose) or the local DoH server will fail
> to start with a bare `EPERM`.

> [!caution] `SocketBind*` needs kernel support
> It is implemented with cgroup BPF `bind4`/`bind6` hooks, which not every kernel or
> container runtime provides. The man page is explicit that unsupported systems get **no
> effect at all** and that you should not rely on it exclusively for security. Confirm with
> the `systemd-analyze security` delta, not by assumption.

> [!warning] Do not add `ProcSubset=pid`
> Tempting, and wrong for this daemon. The man page: *"Linux exposes various kernel APIs via
> /proc/, which are made unavailable with this setting. Since these APIs are used frequently
> this option is useful only in a few, specific cases, and is not suitable for most
> non-trivial programs."* `ProcSubset=pid` hides `/proc/net` and `/proc/sys` along with
> process-irrelevant entries. `ProtectProc=invisible` is the one that is recommended
> generally.

> [!note] `SystemCallFilter=@system-service` is already the right baseline
> It excludes `@clock`, `@mount`, `@swap` and `@reboot` by construction, so piling on
> `~@mount`-style negative lists adds nothing. Add negative syscall groups only when
> `systemd-analyze security` still reports a gap you can name.

### 7. NetworkManager must be told to use the local resolver

This is the step that decides whether any of the above matters. On this host
`/etc/resolv.conf` is regenerated by NetworkManager, so a manual edit is lost on the next
reconnect. The shipped `nsswitch.conf` already carries the harmless
`hosts: … resolve [!UNAVAIL=return] …` line, which is a no-op while `systemd-resolved` is
absent.

```bash
# find the profile that actually carries your default route
nmcli -f NAME,DEVICE,DEVICE-TYPE con show --active
```

```bash
# let nmcli resolve the profile name for the uplink
CON="$(nmcli -t -f NAME,DEVICE con show --active | awk -F: '$2 !~ /^(lo|virbr|veth|docker|br-)/ {print $1; exit}')"
echo "profile: $CON"

nmcli con mod "$CON" \
  ipv4.dns "127.0.0.1"      ipv4.ignore-auto-dns yes \
  ipv6.dns "::1"            ipv6.ignore-auto-dns yes \
  ipv4.dns-options "edns0 trust-ad" \
  ipv4.dns-priority -50

nmcli con up "$CON"
```

| Key | Why |
|---|---|
| `ipv4.dns` / `ipv6.dns` | the loopback resolvers to write into `resolv.conf` |
| `ipv4.ignore-auto-dns yes` | drop the DHCP/DHCPv6-provided resolvers *and* their search list, so the router's `192.168.0.1` never returns |
| `ipv4.dns-options` | carries `edns0` into `options edns0`, and `trust-ad` if you want AD bit |
| `ipv4.dns-priority -50` | negative priority **excludes** every profile with a higher value, which is the DNS-leak lever |

`ipv4.dns-priority` is the one that matters once a VPN is involved. Per the manual, a
negative value means *"in presence of at least one negative priority, only DNS servers from
connections with the lowest priority value will be used"*, and the defaults are 50 for VPNs
and 100 for everything else. So `-50` on the uplink profile beats a connected VPN's default
`50` — a VPN that pushes its own resolvers cannot win, and traffic cannot silently escape
the local proxy.

> [!warning] `dns=loopback` cannot be set through nmcli 1.58
> NetworkManager has a `dns` connection property whose `loopback` value is the tidier
> route, but nmcli 1.58.1 refuses it:
> `Error: invalid property 'dns': 'dns' is ambiguous: dns-over-tls, dnssec.`
> The property exists in `libnm`; it is only reachable through the keyfile plugin or D-Bus.
> The `ipv4.dns` + `ignore-auto-dns` route above works on every version.

> [!caution] `ignore-auto-dns` is per-profile
> It only suppresses the resolvers that *that* profile received automatically. Set it on
> every profile that can be active — the uplink, each Wi-Fi profile, and each VPN — or use
> `ipv4.dns-priority -50` on the one you want to win.

### 8. Ordering and failure behaviour

The shipped units already declare `Wants=network-online.target nss-lookup.target` and
`Before=nss-lookup.target`, so NSS waits for DNS to be ready. Both units are
`WantedBy=multi-user.target` / `sockets.target` respectively. No extra ordering glue is
needed; if you change the socket's `ListenStream=` lines by hand, that is a unit file edit
and *does* need `systemctl daemon-reload`.

## Gotchas

> [!danger] Enabling both units
> Service mode with a non-empty `listen_addresses` *and* socket activation means two
> components own port 53. Symptom is intermittent resolution failure with no obvious cause.
> Keep exactly one enabled.

> [!danger] Leaving `listen_addresses` set in socket mode
> Upstream is explicit: with socket activation it *"must be set to empty"*. And with
> `ignore_system_dns = true`, the daemon cannot resolve its own resolvers list through
> itself — the config flags internal lookups as *"incompatible with systemd sockets"*. In
> socket mode either leave the list cached, or accept system DNS for the bootstrap lookup
> with `ignore_system_dns = false`.

> [!warning] Blocked queries do not return `NXDOMAIN`
> `blocked_query_response` defaults to `hinfo`, which means *"some responses will be lies"*.
> Testing with `dig` and expecting `NXDOMAIN` — a very common check in blog posts — is
> simply wrong for the default. Use `'refused'`, or `'a:0.0.0.0,aaaa::'` to get a routable
> answer, and test with the option you actually chose.

> [!warning] Updating the blocklist does nothing on its own
> `enable_hot_reload = false` is the default. A nightly job that rewrites
> `blocked-names.txt` leaves the running daemon on the old rules until a restart — silently.

> [!warning] The daemon cannot update its own blocklist
> `ProtectSystem=strict` plus the fact that `/etc` is not one of the `*Directory=` paths
> means any generator must run **outside** the sandbox as root. This is the intended
> arrangement; just do not be surprised when the service cannot self-heal.

> [!caution] `require_dnssec = true` is not validation
> It only filters the candidate resolver list toward DNSSEC-validating resolvers; the daemon
> does not validate the chain itself. It also excludes most resolvers, so it tends to shrink
> the pool to a handful. And if you front the proxy with dnsmasq, disable *dnsmasq's*
> `dnssec` option whenever dnscrypt-proxy does any filtering — upstream calls this out.

> [!caution] `ipv6_servers = true` on a host without working IPv6
> The shipped default is `false` with the comment *"Do not enable if you don't have IPv6
> connectivity"*. Enabling it stalls queries. If you want to stop AAAA lookups leaking to
> slow v6-only resolvers, that is `block_ipv6 = true` — a different mechanism.

> [!note] What the nixCraft / cyberciti guide gets wrong
> Its `pacman -S dnscrypt-proxy` line and its `[blocked_names]` / `blocked_names_file` keys
> are correct. The rest is not usable as written on Arch:
>
> - **No `resolv.conf` step at all.** It never configures how the system reaches the proxy,
>   so on an NM host the router's resolver keeps winning. This is the single biggest gap.
> - **No sandboxing.** The question it never answers.
> - `server_names = [ 'google' 'cloudflare']` is **invalid TOML** — array elements need
>   commas.
> - `require_dnssec = true` is presented as protection while, in the same snippet,
>   `server_names` is set — which makes the `require_*` filters inert.
> - Never mentions `require_nofilter`, so a reader following it will find their
>   ad-blocking resolver silently filtered out of the candidate list.
> - The cron job rewrites the blocklist but never reloads or restarts anything.
> - The verification step insists on `NXDOMAIN`, which the default
>   `blocked_query_response` cannot produce.
> - It enables `dnscrypt-proxy.service` while pasting socket-activation logs
>   (*"Wiring systemd TCP socket #1"*), and never mentions that the two modes are exclusive
>   — the `listen_addresses = []` requirement appears only in a comment from the Fedora
>   maintainer, not in the steps.
>
> Its hand-rolled `update-adblocker.sh` also reimplements, less well, what
> `generate-domains-blocklist` is packaged for: no allowlist, no local additions, no
> time-restricted rules, and it pulls the combined StevenBlack list rather than a feed
> selection you control.

## Verification

```bash
# 1. the unit you meant is the one running
systemctl is-enabled dnscrypt-proxy.socket dnscrypt-proxy.service
systemctl status dnscrypt-proxy.socket --no-pager

# 2. port 53 is held by the expected component
ss -lpn 'sport = :domain'

# 3. the sandbox is actually applied (expect ProtectProc=invisible, ProtectClock=yes)
systemctl show dnscrypt-proxy.service -p ProtectProc -p ProtectClock \
  -p RestrictSUIDSGID -p DynamicUser -p ProtectSystem
systemd-analyze security dnscrypt-proxy.service --no-pager | tail -5

# 4. the system is pointed at the local proxy, not the router
cat /etc/resolv.conf
nmcli -f IP4.DNS,IP6.DNS device show "$(nmcli -g GENERAL.DEVICE con show --active | head -1)"

# 5. a normal lookup resolves
dig +short @127.0.0.1 example.com

# 6. ad-blocking: pick a name from YOUR list, and check the block log
dig @127.0.0.1 pagead2.google.com
sudo tail -5 /var/log/dnscrypt-proxy/blocked-names.log

# 7. no plaintext leak to the router
sudo tcpdump -ni any port 53 and not host 127.0.0.1
```

Expected readings, not just commands:

- Step 4: `resolv.conf` says `nameserver 127.0.0.1` (and `::1`), **not** `192.168.0.1`,
  and the `# Generated by NetworkManager` header is still there — that is correct, the
  content is what you changed.
- Step 6: with the default `blocked_query_response = 'hinfo'` you get an answer with no
  records, not `NXDOMAIN`. An entry in `blocked-names.log` is the definitive proof your
  *local* layer fired.
- Step 7: no packets to port 53 leaving the interface. Anything else is a leak — check
  step 4 first.
- Then confirm encryption end-to-end at <https://1.1.1.1/help/> or
  <https://dnsleaktest.com> (extended test).

## Related

- [[Vault Conventions]] — the schema this note follows
- [[dnscrypt-proxy-tor]] — composing this daemon with a Tor SOCKS egress, for host and
  containers, plus the collision rules against the running searxng stack
- [[systemd-exec-hardening]] — placeholder: the general hardening vocabulary
- [[NetworkManager]] — placeholder: connection profile properties in depth
- [[DNS-over-HTTPS]] — placeholder: protocol background and stamp format
- [[arch-system-audit]] — the other machine-specific note in this vault

## Sources

- [ArchWiki: dnscrypt-proxy](https://wiki.archlinux.org/title/Dnscrypt-proxy) — activation
  modes, the service/socket exclusivity rule, resolv.conf coordination, local cache
  topologies
- [Arch packaging repo: PKGBUILD, `dnscrypt-proxy.service`, `dnscrypt-proxy.socket`](https://gitlab.archlinux.org/archlinux/packaging/packages/dnscrypt-proxy) —
  version 2.1.18, file list, and the shipped sandbox directives quoted in §6
- [upstream 2.1.18 `example-dnscrypt-proxy.toml`](https://github.com/DNSCrypt/dnscrypt-proxy/blob/2.1.18/dnscrypt-proxy/example-dnscrypt-proxy.toml) —
  every key and section name in §3–§5, including that `server_names` bypasses `require_*`
  and that socket activation is incompatible with `ignore_system_dns`
- [`systemd.resource-control(5)`](https://man.archlinux.org/man/systemd.resource-control.5.en) —
  `SocketBindAllow=` / `SocketBindDeny=` grammar, precedence, BPF implementation, caveats
- [`systemd.exec(5)`](https://man.archlinux.org/man/systemd.exec.5.en) — `DynamicUser=`
  implications, `ProtectProc=invisible` vs `ProcSubset=pid`, `RestrictFileSystems=`
- [upstream `public-resolvers.md`](https://github.com/DNSCrypt/dnscrypt-resolvers/blob/master/v3/public-resolvers.md) —
  the resolver short names in §3 and the "incompatible with anonymization" warning
- [`generate-domains-blocklist` upstream sources](https://github.com/DNSCrypt/dnscrypt-proxy/tree/2.1.18/utils/generate-domains-blocklist) —
  flag names and the four data files
- [`nm-settings-nmcli(5)`](https://man.archlinux.org/man/nm-settings-nmcli.5.en) —
  `ipv4.dns-priority` semantics, `ignore-auto-dns`, `ipv4.dns-options`
- [nixCraft: install dnscrypt-proxy with adblocker](https://www.cyberciti.biz/faq/how-to-install-dnscrypt-proxy-with-adblocker-on-linux/) —
  read as a counter-example; see the Gotchas section for the itemised list of what it gets
  wrong

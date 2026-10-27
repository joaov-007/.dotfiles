---
title: "SearXNG behind Tor — Wiki-First Metasearch on Compose and Quadlet"
aliases:
  - SearXNG Tor
  - searxng tor deploy
  - tor metasearch
  - wiki search engine
  - searxng quadlet
description: >-
  Deploy a private SearXNG whose engine traffic egresses through a Tor sidecar: the compose
  stack, the equivalent Podman Quadlet units, the `outgoing` `socks5h` proxy contract, and a
  wiki-first engine list — every Wikimedia project plus a curated few — that survives Tor exits
  where scrape engines only return CAPTCHAs.
tags:
  - searxng
  - metasearch
  - tor
  - anonymity
  - privacy
  - containers
  - podman
  - quadlet
  - compose
  - wikimedia
  - mediawiki
  - arch-linux
categories: containers
type: guide
status: evergreen
created: 2026-10-12
updated: 2026-10-14
last_reviewed: 2026-10-12
review_after: 2027-04-12
language: en
audience: sysadmin
scope: >-
  Running SearXNG with all engine traffic through a Tor SOCKS5 sidecar — compose and Quadlet
  layouts, the outgoing: proxy settings, and a Wikimedia-first engine selection. Tor itself is
  covered in [[tor]], not here.
platform:
  - arch-linux
  - podman
  - systemd
keywords:
  - searxng
  - searxng-core
  - searxng-tor
  - valkey
  - dperson/torproxy
  - socks5h
  - using_tor_proxy
  - extra_proxy_timeout
  - isTor
  - wikimedia
  - wikipedia
  - wikidata
  - wiktionary
  - mediawiki
  - quadlet
sources:
  - "[SearXNG docs: `outgoing:` settings](https://docs.searxng.org/admin/settings/settings_outgoing.html)"
  - "[SearXNG docs: `engines:` settings](https://docs.searxng.org/admin/settings/settings_engines.html)"
  - "[SearXNG docs: Installation container](https://docs.searxng.org/admin/installation-docker.html)"
  - "[SearXNG container compose template](https://raw.githubusercontent.com/searxng/searxng/master/container/docker-compose.yml)"
  - "[SearXNG source: searx/settings_defaults.py](https://github.com/searxng/searxng/blob/master/searx/settings_defaults.py)"
  - "[dperson/torproxy (Tor + Privoxy image)](https://hub.docker.com/r/dperson/torproxy)"
  - "[podman-systemd.unit(5) — Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)"
  - "[ArchWiki: Podman § Quadlet](https://wiki.archlinux.org/title/Podman)"
source_retrieved: 2026-10-12
related:
  - "[[Home]]"
  - "[[tor]]"
  - "[[podlet-compose-to-quadlet]]"
  - "[[Quadlet]]"
  - "[[podman-registries]]"
  - "[[container-registries]]"
  - "[[arch-dnscrypt-proxy]]"
  - "[[dnscrypt-proxy-tor]]"
  - "[[Vault Conventions]]"
cssclasses:
  - nota-longa
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Write a wiki teaching how to deploy a Tor SearXNG with all Wikimedia engines and a curated few, aggregating the live compose + Quadlet setup"
ai-review: pending
---

# SearXNG behind Tor — Wiki-First Metasearch on Compose and Quadlet

> [!summary] One-paragraph answer
> Run three containers — `searxng`, `valkey`, and a Tor SOCKS5 sidecar — on one Podman network.
> Point SearXNG's `outgoing.proxies` at `socks5h://searxng-tor:9050` and set
> `using_tor_proxy: true`; every engine request then leaves through Tor. Because Tor exits are
> blocked by most scrape engines, make the instance **wiki-first**: enable every Wikimedia
> project engine (they tolerate Tor) and drop the mainstream ones. Ship the stack either as a
> `compose.yml`, or as Quadlet units so systemd owns it. The whole recipe is verified on host
> `bacon` (Podman + Quadlet).

> [!note] Where this sits next to [[tor]]
> [[tor]] covers the Tor *daemon* on Arch — SOCKS, ControlPort, bridges, relays. This note is
> the *consumer* side: putting a containerized SearXNG behind Tor and choosing engines that
> actually work there.

## Context

You want a private metasearch instance that does not leak your queries to your ISP, the site, or
a central provider. SearXNG is a metasearch front end: it fans one query out to many engines and
merges the results. For that to be private, its **outbound** engine requests must egress through
Tor, not just your browser session.

The catch is engine quality. Tor exit IPs are shared, so Google, Bing, Brave, DuckDuckGo, Qwant
and Yahoo rate-limit, CAPTCHA or outright block them. Wikimedia's MediaWiki APIs do not — they
are the sweet spot. A Tor-routed SearXNG that leans on Wikipedia/Wikidata/Wiktionary and friends
returns clean, stable results; one that leans on scrape engines spends its time showing captchas.
So this recipe is deliberately **wiki-first**.

You are in the right place if you have Podman (or Docker) and want the whole instance —
`searxng` + `valkey` (cache/limiter) + Tor — reproducible as text.

## Details

### 1. Architecture

Three containers on one user-defined network. Names matter: the compose **service name** and the
Quadlet **`ContainerName`** both become the DNS name other containers resolve.

| Container | Image | Role | Reaches |
|---|---|---|---|
| `searxng` (`core`) | `docker.io/searxng/searxng:latest` | the app; port `8080` | `searxng-tor:9050`, `searxng-valkey:6379` |
| `searxng-tor` | `docker.io/dperson/torproxy:latest` | SOCKS5 `9050` + Privoxy HTTP `8118` | the Tor network |
| `searxng-valkey` | `docker.io/valkey/valkey:9-alpine` | result cache + rate limiter | — |

`dperson/torproxy` is the Tor-plus-Privoxy image; its SOCKS port `9050` is the one SearXNG uses.
The container is a plain client — no `torrc`, no relay.

> [!important] Nothing is routed until SearXNG is *told* to use the proxy
> Putting the Tor container on the same network only makes it **reachable**, not **used**. The
> `outgoing.proxies` setting in §3 is what actually sends traffic through it.

### 2. Compose stack

`compose.yml` — the core service waits for both valkey and Tor to be healthy before starting:

```yaml
name: searxng
services:
  core:
    container_name: searxng-core
    image: docker.io/searxng/searxng:latest
    restart: always
    environment:
      - SEARXNG_BASE_URL=http://localhost:8080
      - SEARXNG_VALKEY_URL=valkey://valkey:6379/0
    volumes:
      # the directory that holds settings.yml; :ro keeps the container out of your files
      - .:/etc/searxng/:ro,Z
      - core-data:/var/cache/searxng/
    ports:
      - "${SEARXNG_PORT:-8080}:${SEARXNG_PORT:-8080}"
    depends_on:
      valkey:
        condition: service_healthy
      searxng-tor:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "python3", "-c", "import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8080/healthz', timeout=5).status==200 else 1)"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 40s

  searxng-tor:
    container_name: searxng-tor
    image: docker.io/dperson/torproxy:latest
    restart: always
    # published on loopback only; SearXNG reaches it internally at searxng-tor:9050
    ports:
      - "127.0.0.1:9050:9050"
      - "127.0.0.1:8118:8118"
    healthcheck:
      test: ["CMD", "nc", "-z", "127.0.0.1", "9050"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 60s

  valkey:
    container_name: searxng-valkey
    image: docker.io/valkey/valkey:9-alpine
    command: valkey-server --save 30 1 --loglevel warning
    restart: always
    volumes:
      - valkey-data:/data/
    healthcheck:
      test: ["CMD", "valkey-server", "--version"]
      interval: 10s
      timeout: 5s
      retries: 3
      start_period: 10s

volumes:
  core-data:
  valkey-data:
```

Notes on the choices:

- `SEARXNG_VALKEY_URL`, not the old `SEARXNG_REDIS_URL` — recent images read the Valkey variable.
- Mounting `.` (the project dir) read-only means the container sees exactly the `settings.yml`
  you edit, and `:Z` relabels for SELinux (inert on Arch/AppArmor).
- Do **not** drop the Tor `ports:` block and do **not** widen it to `0.0.0.0` — see Gotchas.

### 3. The Tor proxy contract — `settings.yml`

ONLY `socks5h://` is accepted when `using_tor_proxy` is on. The host is the Tor container's DNS
name on the shared network.

```yaml
use_default_settings: true

outgoing:
  pool_connections: 15
  enable_http2: true
  # every engine goes through the Tor sidecar
  proxies:
    all://:
      - socks5h://searxng-tor:9050
  using_tor_proxy: true
  # extra seconds added to each engine timeout to absorb Tor latency
  extra_proxy_timeout: 10
```

| Setting | Why |
|---|---|
| `proxies: all://:` | matches every engine; list several proxies for round-robin |
| `socks5h://` | the `h` makes the **exit node** resolve hostnames — no local DNS leak |
| `using_tor_proxy: true` | fail-closed: SearXNG checks `check.torproject.org/api/ip` and refuses to serve unless the egress reports `IsTor` |
| `extra_proxy_timeout` | adds slack on top of each engine's own timeout; Tor circuits are slow to warm |

> [!danger] `extra_proxy_timeout` must be an **integer**
> The docs write `10.0`. The settings schema rejects a float with
> `ERROR:searx:outgoing.extra_proxy_timeout: The value has to be one of these types/values: int`
> and then `ValueError: Invalid settings.yml`. Use `10`, not `10.0`.

### 4. Wiki-first engines — all wikis, plus a curated few

SearXNG ships every Wikimedia engine already defined; six of them are `disabled: true` by default,
so "enable all wikis" means listing them with `disabled: false`. Add them under `engines:`.

**All Wikimedia projects:**

```yaml
engines:
  - { name: wikipedia,          disabled: false }
  - { name: wikidata,           disabled: false }
  - { name: wikibooks,          disabled: false }
  - { name: wikinews,           disabled: false }
  - { name: wikiquote,          disabled: false }
  - { name: wikisource,         disabled: false }
  - { name: wikispecies,        disabled: false }
  - { name: wiktionary,         disabled: false }
  - { name: wikiversity,        disabled: false }
  - { name: wikivoyage,         disabled: false }
  # Commons media (own categories: images / videos / music / files)
  - { name: wikicommons.images, disabled: false }
  - { name: wikicommons.videos, disabled: false }
  - { name: wikicommons.audio,  disabled: false }
  - { name: wikicommons.files,  disabled: false }
```

**A few wikis only** — when you want Wikipedia + definitions + source texts and nothing else:

```yaml
engines:
  - { name: wikipedia,  disabled: false }
  - { name: wikidata,   disabled: false }
  - { name: wiktionary, disabled: false }
  - { name: wikisource, disabled: false }
```

**Language and API behavior** — Wikimedia results follow your locale unless you pin a language or
add a second engine. These are engine-level keys, useful for an `en` + native pairing:

```yaml
  - name: wikipedia
    disabled: false
    # language: en            # pin instead of following search.default_lang: auto
  - name: wikipedia pt
    engine: wikipedia
    base_url: https://pt.wikipedia.org/
    language: pt
    disabled: false
```

**Bang shortcuts** (type `!wq recife` etc.) — handy for a wiki-first instance:

| Engine | Bang | Category | Default state |
|---|---|---|---|
| wikipedia | `!wp` | general | on |
| wikidata | `!wd` | general | on |
| wikinews | `!wn` | news | on |
| wiktionary | `!wt` | dictionaries | on |
| wikibooks | `!wb` | general | **off** |
| wikiquote | `!wq` | general | **off** |
| wikisource | `!ws` | general | **off** |
| wikispecies | `!wsp` | general, science | **off** |
| wikiversity | `!wv` | general | **off** |
| wikivoyage | `!wy` | general | **off** |

> [!tip] If you must keep a scrape engine, scope Tor per engine
> You do not have to route everything through Tor. Define a named network under
> `outgoing.networks` and reference it from a single engine with `network: <name>`, leaving the
> rest direct. Trade-off: that engine's queries are no longer anonymous.

### 5. The same stack as Quadlet units

To let systemd own the containers instead of a compose wrapper, translate the compose file with
`podlet` (see [[podlet-compose-to-quadlet]]) or write the units directly. They live in
`~/.config/containers/systemd/`.

`searxng.network`:

```ini
[Network]
Subnet=10.247.1.0/24
```

`searxng-tor.container`:

```ini
[Unit]
Description=SearXNG Tor SOCKS5 egress
After=network-online.target
Wants=network-online.target

[Container]
ContainerName=searxng-tor
Image=docker.io/dperson/torproxy:latest
Network=searxng.network
PublishPort=127.0.0.1:9050:9050
PublishPort=127.0.0.1:8118:8118
HealthCmd=["CMD","nc","-z","127.0.0.1","9050"]
HealthInterval=30s
HealthTimeout=5s
HealthRetries=3
HealthStartPeriod=60s
Notify=healthy

[Service]
Restart=always

[Install]
WantedBy=default.target
```

`searxng-valkey.container`:

```ini
[Container]
ContainerName=searxng-valkey
Image=docker.io/valkey/valkey:9-alpine
Network=searxng.network
Exec=valkey-server --save 30 1 --loglevel warning
Volume=searxng-valkey.volume:/data:Z
HealthCmd=["valkey-server","--version"]
Notify=healthy

[Service]
Restart=always

[Install]
WantedBy=default.target
```

`searxng.container` — note `Requires=`/`After=` for **both** dependencies; that is the Quadlet
equivalent of `depends_on`:

```ini
[Unit]
Description=SearXNG Meta Search Engine
Requires=searxng-tor.service searxng-valkey.service
After=searxng-tor.service searxng-valkey.service

[Container]
ContainerName=searxng
Image=docker.io/searxng/searxng:latest
Network=searxng.network
PublishPort=127.0.0.1:9081:8080
Environment=SEARXNG_BASE_URL=http://127.0.0.1:9081/ SEARXNG_VALKEY_URL=valkey://searxng-valkey:6379/0 SEARXNG_SECRET=<generate-with-openssl-rand-hex-32>
# read-only bind of the host config dir; no :U, so the container cannot chown/edit it
Volume=/home/USER/.config/searxng:/etc/searxng:ro,Z
Volume=searxng-cache.volume:/var/cache/searxng:Z
HealthCmd=["python3","-c","import urllib.request,sys; sys.exit(0 if urllib.request.urlopen('http://localhost:8080/healthz', timeout=5).status==200 else 1)"]
HealthStartPeriod=40s
Notify=healthy

[Service]
Restart=always

[Install]
WantedBy=default.target
```

With `Network=searxng.network`, the Quadlet **container name** (`searxng-tor`) is the DNS alias the
core resolves — so the host in `settings.yml` is `searxng-tor` in both layouts.

### 6. Bring-up and reload

Compose:

```bash
podman-compose up -d          # or: docker compose up -d
podman-compose logs -f core
```

Quadlet:

```bash
systemctl --user daemon-reload
systemctl --user start searxng.service searxng-tor.service searxng-valkey.service
sudo loginctl enable-linger "$USER"    # keep them up without an open session
```

`settings.yml` is hot-reloaded on a running instance, but a container restart makes it
unambiguous:

```bash
systemctl --user restart searxng.service     # Quadlet
podman restart searxng-core                  # compose
```

## Gotchas

> [!danger] A float in `extra_proxy_timeout` crash-loops the service
> The docs show `10.0`; the schema wants an int. The symptom under `Restart=always` is a
> restart storm with `ValueError: Invalid settings.yml` and `NRestarts` climbing. The real line
> (`outgoing.extra_proxy_timeout: The value has to be one of these types/values: int`) is only in
> the journal — `journalctl --user -u searxng.service`. Use `10`.

> [!warning] `using_tor_proxy: true` rejects any non-`socks5h` proxy
> One `socks5://` (or `http://`) entry makes the Tor self-check fail and the client raises
> `ProxyError: Network configuration problem: not using Tor`, surfaced at boot as
> `RuntimeError: Invalid network configuration`. Every proxy must be `socks5h://`. This is the
> usual cause of "enabling `using_tor_proxy` broke my instance".

> [!warning] The first search after boot can return zero results
> Tor builds circuits lazily. On a cold container the first query may finish with everything
> "unresponsive"; warm circuits fix it and the next query returns normally. Raise
> `request_timeout` if you want to hide that first hit.

> [!caution] `localhost:9050` is wrong inside a container
> `localhost` is the container's own loopback, not the Tor sidecar. Use the service/container
> name (`socks5h://searxng-tor:9050`). It only becomes correct with `network_mode: host`.

> [!warning] Never publish Tor's SOCKS port off loopback
> `-p 0.0.0.0:9050:9050`, or binding host Tor to `0.0.0.0`, turns the machine into an open Tor
> proxy. Publish on `127.0.0.1` if you need host access at all, or leave it unpublished — the
> containers reach it over the shared network without any `ports:` entry.

> [!caution] The config mount must point at the dir holding `settings.yml`
> Mounting a path that does not exist (e.g. a `./core-config/` you never created, or a missing
> `env_file: ./.env`) makes compose fail or silently start SearXNG on stock defaults — Tor never
> engages. Mount the directory that actually contains `settings.yml`.

> [!note] Wiki engines are the stable floor, not a limitation you should fight
> Over Tor, `!wp`/`!wd`/`!wt` answer reliably while `!bi`/`!ddg`/`!br` mostly do not. Build the
> instance around the wikis, and treat scrape engines as best-effort.

## Verification

```bash
# 1. settings parse BEFORE booting the stack (catches the float/int and socks5h traps)
podman run --rm -v "$PWD":/etc/searxng:ro \
  --entrypoint /usr/local/searxng/.venv/bin/python \
  docker.io/searxng/searxng:latest \
  -c 'import searx; searx.init_settings(); print("SETTINGS OK")'
# expect: SETTINGS OK

# 2. the Tor sidecar is healthy and its SOCKS port answers
podman exec searxng-tor nc -z 127.0.0.1 9050 && echo "socks up"

# 3. SearXNG genuinely opens connections to the sidecar (port 9050 = hex 235A)
#    run a search, then count established connections during it
curl -s -A 'Mozilla/5.0' 'http://127.0.0.1:8080/search' --data-urlencode 'q=arch linux' -o /tmp/s.html -w 'http=%{http_code} time=%{time_total}s\n'
podman exec searxng sh -c 'cat /proc/net/tcp /proc/net/tcp6' | awk '$4=="01"{print $3}' | grep -c ':235A$'
# expect: a non-zero count, falling to 0 when the search ends

# 4. the egress really is Tor
podman run --rm --network searxng_default docker.io/curlimages/curl:latest \
  -s --socks5-hostname searxng-tor:9050 https://check.torproject.org/api/ip
# expect: {"IsTor":true, ...}

# 5. results arrive, and the wiki engines answer first
grep -o 'class="result [^"]*"' /tmp/s.html | wc -l         # > 0 after circuits are warm
podman logs searxng-core 2>&1 | grep -iE 'Invalid settings|ProxyError|not using Tor'   # expect nothing
```

Expected readings, not just commands:

- Step 1 is the cheapest guard: it fails with the exact schema message instead of a container
  restart loop.
- Step 3: a **non-zero** transient count on `:235A` while a query runs is the only direct proof
  SearXNG is *using* Tor, not merely coexisting with it.
- Step 4: `"IsTor":true`. If it is `false`, the proxy host is wrong.
- Step 5: results after warm-up; a consistently empty page means every engine is timing out or
  blocked — check the host in `settings.yml` and lean harder on the wiki engines.

## Related

- [[tor]] — the daemon side: SOCKS, ControlPort, bridges, relays, and `socks5` vs `socks5h`
- [[podlet-compose-to-quadlet]] — generating these Quadlet units from the compose file, and the
  three ways several containers can share one Tor container
- [[Quadlet]] — the unit reference for `[Container]` keys, resources and debugging
- [[podman-registries]] — image/registry basics for pulling the three images
- [[arch-dnscrypt-proxy]] — the other local resolver; do not let it and Tor DNS both claim port 53
- [[dnscrypt-proxy-tor]] — routing DNS through Tor with its own egress; keeps clear of this
  stack's published `9050`/`8118` (see its coexistence section)
- [[Vault Conventions]] — the schema this note follows

## Sources

- [SearXNG docs: `outgoing:`](https://docs.searxng.org/admin/settings/settings_outgoing.html) —
  `proxies`, `using_tor_proxy`, `socks5h` guidance and the timeout keys in §3
- [SearXNG docs: `engines:`](https://docs.searxng.org/admin/settings/settings_engines.html) —
  per-engine `disabled`, `proxies`, `using_tor_proxy`, `language`, `base_url`
- [SearXNG docs: Installation container](https://docs.searxng.org/admin/installation-docker.html) —
  the `/etc/searxng` mount, env vars and the compose workflow in §2
- [SearXNG container compose template](https://raw.githubusercontent.com/searxng/searxng/master/container/docker-compose.yml) —
  canonical service/image names and the port interpolation
- [searx/settings_defaults.py](https://github.com/searxng/searxng/blob/master/searx/settings_defaults.py) —
  the schema that requires an int for `extra_proxy_timeout` and the `socks5h`-only Tor check
- [dperson/torproxy](https://hub.docker.com/r/dperson/torproxy) — the SOCKS5 `9050` / Privoxy
  `8118` port map used by the sidecar
- [podman-systemd.unit(5)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) —
  `[Container]`, `Network=`, `HealthCmd`, `Notify=healthy`, unit search paths
- [ArchWiki: Podman](https://wiki.archlinux.org/title/Podman) — rootless Quadlet, lingering,
  `podman-system-generator --dryrun` and `quadlet -dryrun`

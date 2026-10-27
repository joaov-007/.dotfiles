---
title: "Convert Compose to Quadlet with Podlet"
aliases:
  - Podlet
  - podlet compose
  - Compose to Quadlet
  - Compose to systemd Podman
  - Quadlet from compose
description: >-
  Turn a compose.yaml into Podman Quadlet systemd units with podlet: generate
  .container/.pod/.kube files, drop them in the right unit directory, and
  activate them with systemctl --user on Arch.
tags:
  - containers
  - podman
  - quadlet
  - podlet
  - systemd
  - compose
  - devops
  - arch-linux
categories: containers
type: guide
status: evergreen
created: 2026-10-11
updated: 2026-10-11
last_reviewed: 2026-10-11
review_after: 2027-04-11
language: en
audience: devops
scope: converting a compose file into Podman Quadlet (systemd) units with podlet
platform:
  - Linux
  - Podman
  - systemd
keywords:
  - podlet
  - quadlet
  - podman
  - compose
  - docker-compose
  - systemd generator
  - container unit
  - podman-systemd.unit
  - quadlet install
  - .container
sources:
  - "[Podlet README](https://github.com/containers/podlet)"
  - "[podman-systemd.unit(5) — Quadlet](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)"
  - "[podman-quadlet-install(1)](https://docs.podman.io/en/stable/markdown/podman-quadlet-install.1.html)"
  - "[Arch Wiki — Podman § Quadlet](https://wiki.archlinux.org/title/Podman#Quadlet)"
  - "[Arch Linux package — podlet](https://archlinux.org/packages/extra/x86_64/podlet/)"
source_retrieved: 2026-10-11
related:
  - "[[Home]]"
  - "[[podman-registries]]"
  - "[[container-registries]]"
  - "[[tor]]"
  - "[[arch-setup]]"
  - "[[Quadlet]]"
  - "[[Podman]]"
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Create a tutorial on converting compose.yaml to systemd/Quadlet container files with podlet"
ai-review: pending
cssclasses:
  - nota-longa
---

# Convert Compose to Quadlet with Podlet

> [!summary] One command, one directory, one daemon-reload
> `podlet compose compose.yaml` rewrites a Compose file as **Quadlet** units —
> `.container` files (plus `.volume`, `.network`, `.pod` when needed) that Podman
> feeds to systemd through a generator. Drop them in `~/.config/containers/systemd/`,
> run `systemctl --user daemon-reload`, then `systemctl --user start <name>.service`.
> Quadlet is Podman's native systemd integration: no daemon, no `podman-compose`
> wrapper left running. `podlet` only *generates* the units — always read them before
> starting.

## Context

You have a `compose.yaml` and want the stack managed by systemd rather than
`podman-compose up`: start on boot, `Restart=` policy, journald logs, unit
dependencies, resource limits. There are two ways to get there:

- keep the Compose file and run it under a systemd unit that calls `podman-compose`
  (fragile — the wrapper is the service), or
- **translate** the Compose file into Quadlet units that systemd owns directly.

`podlet` does the translation. This note covers Arch installation, generating from a
compose file, where the files go, activating them, and the failure modes that
actually bite.

## Details

### 1. Install

On Arch, `podlet` lives in **extra** and pulls only `glibc`/`libgcc`; it is an
optional dependency of `podman`.

```bash
sudo pacman -S podman podlet
```

Other channels (upstream): prebuilt binaries from the GitHub releases, `cargo install podlet`,
`cargo binstall podlet`, `brew install podlet`, or the container
`podman run ghcr.io/containers/podlet`. Verify:

```bash
podlet --version   # e.g. podlet 0.3.2
podman --version   # Quadlet needs Podman 4.4+
```

Quadlet also requires **cgroup v2** — on Arch this is the default. Check with
`podman info --format '{{.Host.CgroupsVersion}}'`.

### 2. What Quadlet is

Quadlet is a **systemd generator** shipped with Podman. It reads files in a set of
search directories, and for each one generates a matching `.service` unit at boot and
at every `systemctl daemon-reload`. Quadlet units keep their Podman-specific keys in
a custom section (`[Container]`, `[Pod]`, …) and pass every other section
(`[Unit]`, `[Service]`, `[Install]`) straight to systemd.

| File | Purpose |
|---|---|
| `*.container` | One container (`podman run`) |
| `*.pod` | A pod several containers join (`podman pod create`) |
| `*.volume` | A named Podman volume |
| `*.network` | A Podman network |
| `*.kube` | Deploy containers from a Kubernetes YAML |
| `*.build` / `*.image` / `*.artifact` | Build/pull/cache units |

Search paths (first hit wins):

| Scope | Directories |
|---|---|
| Rootless | `$XDG_CONFIG_HOME/containers/systemd/` (or `~/.config/containers/systemd/`), `/etc/containers/systemd/users/$UID`, `/etc/containers/systemd/users/` |
| Rootful | `/run/containers/systemd/`, `/etc/containers/systemd/`, `/usr/share/containers/systemd/` (earlier wins) |

A `$name.container` file becomes `$name.service` and a container named
`systemd-$name`. Quadlet also auto-resolves references: `Volume=foo.volume:/data`
and `Network=bar.network` wire up the corresponding units.

### 3. Generate from a compose file

The only required argument to `podlet` is the subcommand. Given:

```yaml
# compose.yaml
name: caddy
services:
  caddy:
    image: docker.io/library/caddy:latest
    ports:
      - "8000:80"
      - "8443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:Z
      - caddy-data:/data
    restart: unless-stopped
volumes:
  caddy-data:
```

`podlet compose compose.yaml` prints the units to stdout:

```ini
# FileName=caddy
[Container]
Image=docker.io/library/caddy:latest
PublishPort=8000:80
PublishPort=8443:443
Volume=./Caddyfile:/etc/caddy/Caddyfile:Z
Volume=caddy-data:/data

[Service]
Restart=always
```

Notes on the mapping:

- The `# FileName=` comment is consumed by `podman quadlet install` and by
  `--quadlets-file`; it is not a systemd key.
- Compose `restart: unless-stopped` becomes `[Service] Restart=always`.
- The file name comes from the top-level `name:` (or the service name); override with `-n`/`--name`.
- If a `volumes:`/`networks:` entry carries options, podlet emits a matching
  `.volume`/`.network` unit instead of inlining it.

If no file is given, podlet looks in the current directory for, in order:
`compose.yaml`, `compose.yml`, `docker-compose.yaml`, `docker-compose.yml`,
`podman-compose.yaml`, `podman-compose.yml`.

### 4. Write the units

Printing to stdout is a preview. To write files:

```bash
# Write separate files into a directory
podlet --install --description Caddy -f ./quadlet compose compose.yaml
# -> Wrote to file: ./quadlet/caddy.container

# Write straight into the Podman unit directory (must already exist!)
mkdir -p ~/.config/containers/systemd
podlet --install -u compose compose.yaml

# Bundle every unit into one .quadlets file (writes to CWD unless -f is set)
podlet --quadlets-file caddy compose compose.yaml
```

Useful global options:

| Option | Effect |
|---|---|
| `-f, --file [DIR]` | Write file(s) instead of stdout (a directory for `compose`) |
| `-u, --unit-directory` | Shortcut to `--file $XDG_CONFIG_HOME/containers/systemd/` (or `/etc/containers/systemd/` as root) |
| `--quadlets-file NAME` | One `<NAME>.quadlets` file, sections separated by `---` |
| `-i, --install` | Add `[Install] WantedBy=default.target` so the unit starts on boot |
| `-d, --description TEXT` | Add `Description=` to `[Unit]` |
| `--service-name NAME` | Rename the generated service (`ServiceName=`) |
| `-a, --absolute-host-paths` | Freeze relative host paths to absolute ones at generation time |
| `-p, --podman-version N` | Target an older Podman (see Gotchas) |
| `--skip-services-check` | Don't abort on an existing service with the same name |

The generated file for the command above:

```ini
[Unit]
Description=Caddy

[Container]
Image=docker.io/library/caddy:latest
PublishPort=8000:80
PublishPort=8443:443
Volume=./Caddyfile:/etc/caddy/Caddyfile:Z
Volume=caddy-data:/data

[Service]
Restart=always

[Install]
WantedBy=default.target
```

You can also install a multi-unit `.quadlets` file with Podman itself, which copies
it to the user unit directory and reloads systemd:

```bash
podlet --quadlets-file caddy compose compose.yaml
podman quadlet install caddy.quadlets
```

### 5. Pod or Kubernetes instead of separate containers

`podlet compose` creates one `.container` per service by default. Two alternatives:

```bash
# One .pod + linked .containers (ports move to the pod)
podlet compose --pod compose.yaml

# One .kube unit + a Kubernetes Pod YAML
podlet compose --kube compose.yaml
```

`--pod` output puts the published ports on the pod and gives each container
`Pod=caddy.pod`; both options require the top-level `name:` field, and `--kube`
conflicts with `--quadlets-file`.

### 6. Activate the unit

Quadlet units become services only after a generator run, so reload first:

```bash
systemctl --user daemon-reload
systemctl --user start caddy.service
systemctl --user status caddy.service
systemctl --user enable --now ...    # will FAIL — see Gotchas
podman ps                            # container is named systemd-caddy
```

For rootful units use the system manager (`sudo systemctl daemon-reload && sudo systemctl start caddy.service`).

For a rootless unit to come up at boot **without** an open login session, enable
lingering for the user:

```bash
sudo loginctl enable-linger "$USER"
```

### 7. Validate and debug

The generator can dry-run without touching systemd:

```bash
# Rootless; prints every generated service to stdout
/usr/lib/systemd/system-generators/podman-system-generator --user --dryrun

# Or, on Arch, the underlying binary directly
/usr/lib/podman/quadlet -dryrun -user

# Limit to one directory
QUADLET_UNIT_DIRS="$PWD/quadlet" \
  /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun
```

To validate an *installed* unit and its generated result:

```bash
systemd-analyze --user --generators=true verify caddy.service
```

If the generator chokes on a key, it is silent on start — `systemctl start` returns
`Unit caddy.service not found`. That almost always means a syntax error or an option
from a newer Podman than the generator knows.

### 8. One container, many consumers — sharing a Tor (or any) container

Quadlet never duplicates a container. If a web server and a file server both need to
use the same `tor` container, you write **one** `tor.container` and have the others
*reference* it. Quadlet resolves the reference into a systemd dependency
(`Requires=` + `After=tor.service`) and passes `--network container:tor` / `--pod` /
`--network` to `podman run`. systemd starts Tor once; the consumers wait for it.

Three patterns, each with a different reachability/port trade-off.

**A. Reuse Tor's network namespace** — `Network=tor.container`

```ini
# tor.container
[Container]
Image=docker.io/dockurr/tor:latest
ContainerName=tor
# Tor's SOCKS listens on 127.0.0.1:9050 inside this netns

# scraper.container
[Container]
Image=docker.io/example/scraper:latest
Network=tor.container
Environment=ALL_PROXY=socks5h://127.0.0.1:9050
```

The consumer shares Tor's namespace, so it reaches the proxy at `127.0.0.1:9050`.
Quadlet generates `Requires=tor.service`, `After=tor.service`.

> [!warning] A container that joins another's netns cannot publish ports
> `PublishPort=` is silently **discarded** — Podman prints `Port mappings have been
> discarded because "container" network namespace mode does not support them`. Use
> this pattern only for consumers that make *outbound* connections (scrapers, sync
> jobs, download clients). If the consumer must serve a port, use B or C.

**B. Put Tor and the consumers in one pod** — `Pod=tor.pod`

```ini
# tor.pod
[Pod]
PodName=tor
PublishPort=8090:80          # published once, at the pod

# weba.container
[Container]
Image=docker.io/library/nginx:latest
Pod=tor.pod
```

All pod containers share one netns, so they reach Tor at `127.0.0.1:9050` and the
infra container holds the published ports. `podlet compose --pod` generates exactly
this layout. Caveat: the whole pod shares one port space — two services cannot both
listen on the same container port.

**C. Give each container its own netns on a shared Podman network** — `*.network`

```ini
# tor-net.network
[Network]
NetworkName=tor-net
```

```ini
# tor.container
[Container]
Image=docker.io/dockurr/tor:latest
Network=tor-net.network
NetworkAlias=tor
```

```ini
# web.container
[Container]
Image=docker.io/library/nginx:latest
Network=tor-net.network
PublishPort=8090:80
Environment=ALL_PROXY=socks5h://tor:9050
```

Each container keeps its own IP and can publish its own ports; it reaches Tor by the
DNS name `tor` (`--network-alias`). This is the usual choice for two independent
services that must each expose a port but share one Tor.

> [!important] Sharing the container does not by itself route traffic through Tor
> In every pattern, the consumer is merely placed next to Tor and given a stable
> address. It still has to be *told* to use the SOCKS proxy — via `ALL_PROXY` /
> `HTTP_PROXY` / `HTTPS_PROXY`, an app setting, or a transparent redirect such as
> Tor's `TransPort` with in-namespace firewall rules. Proximity is not interception.

## Gotchas

> [!warning] The generated units are a starting point, not a finished config
> Podlet itself says it is "not meant to be an end-all solution" and is "not (yet) a
> validator". It does not understand every Compose option and passes many through
> unchecked. Read the unit before `systemctl start`.

> [!warning] Unsupported Compose options abort the conversion
> `build:` and **Compose interpolation** (`${VAR}`, `.env` substitution) are not
> supported. When podlet meets an option Podman/Quadlet cannot express, it errors out
> and you must remove or comment the offending keys. Generate from an already-resolved
> compose file, not one that relies on variable interpolation.

> [!warning] `-u/--unit-directory` does not create the directory
> If `~/.config/containers/systemd/` is missing, `podlet -u compose` fails with
> `Failed to create/open file: … No such file or directory`. `mkdir -p` it first
> (or use `-f ./dir`). For a different base, `podman quadlet install` handles
> creation for you.

> [!caution] Quadlet services are transient — `systemctl enable` does not work
> `systemctl --user enable caddy.service` fails because the unit is generated at
> runtime, not a real file. Enable-at-boot is expressed *inside the unit* via
> `[Install] WantedBy=default.target` — that is exactly what `podlet -i/--install`
> adds. Without it the unit is startable but not auto-started.

> [!warning] `--service-name` only works for a single unit
> Setting one service name for several generated `.container` files would collide and
> podlet refuses. Use it with `podlet podman run` (one file), not with a multi-service
> `podlet compose`.

> [!warning] `--podman-version` tops out below your Podman
> In podlet 0.3.2 the accepted range is `4.4`–`5.8`, default `5.8`, while Arch may ship
> Podman 6.x. The default target is therefore conservative; only lower it
> (`-p 5.0`, …) when the unit must run on an older Podman, and re-check the file
> afterwards.

> [!caution] Relative host paths move with the unit file
> `Volume=./Caddyfile:/etc/caddy/Caddyfile` is resolved by Quadlet **relative to the
> unit file's directory**. Move the `.container` file (or the `Caddyfile`) and the
> mount silently points elsewhere. `podlet -a/--absolute-host-paths` bakes in absolute
> paths at generation time when the compose file's location is the intended anchor.

> [!note] `:Z` is an SELinux relabel
> Compose files copied from SELinux distros carry volume flags like `:Z`/`:z`. Arch
> runs AppArmor by default, so these are inert — harmless to keep, not required.

## Verification

Confirm the workflow end to end (adjust names/paths to your stack):

```bash
# 1. Generation produced the expected file
ls ~/.config/containers/systemd/caddy.container
grep -q 'WantedBy=default.target' ~/.config/containers/systemd/caddy.container && echo "auto-start set"

# 2. The generator accepts the file and emits a service
QUADLET_UNIT_DIRS="$HOME/.config/containers/systemd" \
  /usr/lib/systemd/system-generators/podman-system-generator --user --dryrun | grep -A1 '^---caddy.service---'
```

Expected: the dry-run prints `---caddy.service---`, an `[X-Container]` section echoing
your keys, and an `ExecStart=/usr/bin/podman run …` line. Then:

```bash
systemctl --user daemon-reload
systemctl --user start caddy.service
systemctl --user is-active caddy.service     # -> active
podman ps --format '{{.Names}}'               # -> systemd-caddy
```

`journalctl --user -u caddy.service -f` shows container output; `systemctl --user is-enabled caddy.service` reports `generated` (this is why `enable` is not the mechanism).

## Related

- [[podman-registries]] — unqualified image search, so short image names resolve during pull
- [[container-registries]] — where the images in your compose file come from
- [[tor]] — a real Compose stack (SearXNG + Tor) that is a natural candidate for this conversion
- [[arch-setup]] — `podman`, `podman-compose` and `podlet` are part of the baseline package list
- [[Quadlet]] — the full unit reference: `[Container]` keys, resources, drop-ins, templates, auto-update, debugging

## Sources

- [Podlet README](https://github.com/containers/podlet) — subcommands, flags, compose→Quadlet mapping, `--pod`/`--kube`, `.quadlets` files, cautions
- [podman-systemd.unit(5)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) — unit search paths, generator behaviour, transient units and `[Install]`, `[Container]` keys, debugging
- [podman-quadlet-install(1)](https://docs.podman.io/en/stable/markdown/podman-quadlet-install.1.html) — `podman quadlet install`, `.quadlets` multi-unit files
- [Arch Wiki — Podman § Quadlet](https://wiki.archlinux.org/title/Podman#Quadlet) — rootless/rootful paths, `/usr/lib/podman/quadlet -dryrun -user`, lingering
- [Arch Linux package — podlet](https://archlinux.org/packages/extra/x86_64/podlet/) — version, repo, licence, dependencies

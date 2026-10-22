---
title: "Quadlet"
aliases:
  - Podman Quadlet
  - podman-systemd.unit
  - Quadlet units
  - Podman systemd units
  - .container units
description: >-
  Quadlet is Podman's systemd integration: declarative .container/.pod/.volume/
  .network/.kube units that a systemd generator turns into services. Covers unit
  types, search paths, the [Container] key reference, activation, boot, resources,
  drop-ins, templates, auto-update, and debugging.
tags:
  - containers
  - podman
  - quadlet
  - systemd
  - devops
  - arch-linux
type: reference
status: evergreen
created: 2026-10-11
updated: 2026-10-11
last_reviewed: 2026-10-11
review_after: 2027-04-11
language: en
audience: devops
scope: declarative Podman containers managed by systemd via Quadlet units
platform:
  - Linux
  - Podman
  - systemd
keywords:
  - quadlet
  - podman
  - systemd
  - systemd generator
  - podman-systemd.unit
  - container unit
  - pod unit
  - volume unit
  - network unit
  - kube unit
  - auto-update
  - lingering
  - drop-in
  - template
sources:
  - "[podman-systemd.unit(5) — Quadlet units](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)"
  - "[podman-quadlet-basic-usage(7)](https://docs.podman.io/en/latest/markdown/podman-quadlet-basic-usage.7.html)"
  - "[podman-quadlet-install(1)](https://docs.podman.io/en/stable/markdown/podman-quadlet-install.1.html)"
  - "[Arch Wiki — Podman § Quadlet](https://wiki.archlinux.org/title/Podman#Quadlet)"
source_retrieved: 2026-10-11
related:
  - "[[Home]]"
  - "[[podlet-compose-to-quadlet]]"
  - "[[podman-registries]]"
  - "[[container-registries]]"
  - "[[tor]]"
  - "[[arch-setup]]"
cssclasses:
  - nota-longa
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Create a teaching note/reference on Podman Quadlet (podman-systemd.unit)"
ai-review: pending
---

# Quadlet

> [!summary] Containers as first-class systemd units
> **Quadlet** is a systemd *generator* shipped with Podman. You write declarative
> unit files — `foo.container`, `foo.pod`, `foo.volume`, `foo.network`, `foo.kube`,
> `foo.image`, `foo.build` — drop them in a search directory, and systemd
> materialises matching services (`foo.service`, `foo-pod.service`, …) at boot and
> on every `daemon-reload`. Unlike `podman generate systemd` (removed), Quadlet is
> the supported, declarative way to run containers under systemd — no daemon, no
> wrapper script, and rootless-first.

## Context

You want a container to be a proper systemd service: start on boot, `Restart=`
policy, journald logs, resource limits, cross-unit dependencies, and `systemctl`
control. Options, roughly in order of preference:

- **Quadlet** — declarative unit files; systemd-native; the current default. This note.
- `podman-compose` under a hand-written unit — the wrapper *is* the service; fragile.
- `podman generate systemd` — **deprecated and removed**; do not use for new work.

If you are starting from a Compose file, generate the Quadlets with
[[podlet-compose-to-quadlet]] and then read this note to understand what the
generator produced and how to refine it.

## Details

### 1. Requirements

| Requirement | Notes |
|---|---|
| Podman ≥ 4.4 | Quadlet ships with Podman; Arch package `podman` is current (6.x here) |
| cgroup v2 | Arch default. Check: `podman info --format '{{.Host.CgroupsVersion}}'` |
| systemd | Both the **system** and **user** managers are supported |
| A search directory | See §4 — the unit file must live in one |

No extra package is needed — Quadlet is inside `podman`. On Arch the generator
binary is `/usr/lib/podman/quadlet`, symlinked as
`/usr/lib/systemd/system-generators/podman-system-generator` (rootful) and
`/usr/lib/systemd/user-generators/podman-user-generator` (rootless).

### 2. The unit types

Each Quadlet file has one Podman-specific section plus the normal systemd sections.

| Extension | Podman section | Generates (from `foo.*`) | Runtime object | Default `Type=` |
|---|---|---|---|---|
| `.container` | `[Container]` | `foo.service` | container `systemd-foo` | `notify` |
| `.pod` | `[Pod]` | `foo-pod.service` | pod `systemd-foo` | `forking` |
| `.volume` | `[Volume]` | `foo-volume.service` | volume `systemd-foo` | `oneshot` |
| `.network` | `[Network]` | `foo-network.service` | network `systemd-foo` | `oneshot` |
| `.kube` | `[Kube]` | `foo.service` | containers from K8s YAML | `notify` |
| `.image` | `[Image]` | `foo-image.service` | pulled image | `oneshot` |
| `.build` | `[Build]` | `foo-build.service` | locally built image | `oneshot` |
| `.artifact` | `[Artifact]` | `foo-artifact.service` | pulled OCI artifact *(experimental)* | `oneshot` |

`ServiceName=` in any section overrides the generated service name; `ContainerName=`,
`PodName=`, `VolumeName=`, `NetworkName=` override the runtime object's name.

### 3. Where the files live

Quadlet reads its search paths, ordered by precedence (earlier wins on a name clash):

| Scope | Directories |
|---|---|
| Rootless | `$XDG_CONFIG_HOME/containers/systemd/` (or `~/.config/containers/systemd/`), `/etc/containers/systemd/users/$UID`, `/etc/containers/systemd/users/` |
| Rootful | `/run/containers/systemd/`, `/etc/containers/systemd/`, `/usr/share/containers/systemd/` |

For a personal rootless setup, everything goes in:

```bash
mkdir -p ~/.config/containers/systemd
```

Quadlet also supports symlinks for the base of the search paths and inside them.

### 4. Your first unit

```ini
# ~/.config/containers/systemd/hello.container
[Unit]
Description=Hello Alpine Container

[Container]
Image=alpine
Exec=echo Hello from Quadlet!

[Install]
WantedBy=default.target
```

`Image=` is the only required `[Container]` key. Place the file, reload, start:

```bash
systemctl --user daemon-reload
systemctl --user start hello.service
journalctl --user -u hello.service        # -> "Hello from Quadlet!"
```

The container is named `systemd-hello`; the service is `hello.service`. For rootful
units, drop the file in `/etc/containers/systemd/` and use `sudo systemctl …`.

### 5. Activation and lifecycle

```bash
systemctl --user daemon-reload        # re-run the generator after any edit
systemctl --user start   foo.service
systemctl --user status  foo.service
systemctl --user stop    foo.service
systemctl --user restart foo.service
journalctl --user -u foo.service -f   # container stdout/stderr (LogDriver=journald)
podman ps                             # container appears as systemd-foo
```

Any edit to a Quadlet file requires `daemon-reload` before the change takes effect —
the generator runs only at boot and at reload.

### 6. Boot behaviour: `[Install]`, not `systemctl enable`

> [!important] Generated units cannot be enabled
> `systemctl --user enable foo.service` fails with
> `Unit /run/user/$UID/systemd/generator/foo.service is transient or generated`.
> `is-enabled` reports `generated`. This is normal — Quadlet has no persistent unit file.

Enable-at-boot is expressed **inside the file**; the generator applies `[Install]`
the way `systemctl enable` would. Only `Alias`, `WantedBy`, `RequiredBy` and
`UpheldBy` are supported:

```ini
[Install]
WantedBy=default.target
```

Use `default.target` for rootless units and `multi-user.target` for rootful ones.
For a **rootless** unit to start at boot without an open login session, enable
lingering once:

```bash
sudo loginctl enable-linger "$USER"
```

### 7. The `[Container]` section

Most keys map one-to-one onto `podman run` flags. A curated set:

| Key | `podman run` | Notes |
|---|---|---|
| `Image=` | image positional | **Required.** Prefer a fully-qualified name |
| `ContainerName=` | `--name` | Default is `systemd-%N` |
| `Exec=` | command after image | Args to the image `ENTRYPOINT`/`CMD` |
| `Entrypoint=` | `--entrypoint` | |
| `Environment=` | `--env` | Repeatable; systemd `Environment=` syntax |
| `EnvironmentFile=` | `--env-file` | Absolute or relative to the unit file |
| `PublishPort=` | `--publish` | `ip:host:container`, `host:container`, `/udp` |
| `ExposeHostPort=` | `--expose` | |
| `Volume=` | `--volume` | `.`-relative paths resolve to the unit's dir |
| `Mount=` | `--mount` | `type=…`; `source=foo.volume` links a volume unit |
| `Tmpfs=` / `ShmSize=` | `--tmpfs` / `--shm-size` | |
| `Network=` | `--network` | `foo.network` links a network unit; `foo.container` reuses a netns |
| `NetworkAlias=` | `--network-alias` | DNS name on the network |
| `Pod=` | `--pod` | Must be `name.pod`; links a pod unit |
| `DNS=` / `DNSSearch=` / `DNSOption=` | `--dns*` | |
| `User=` / `Group=` | `--user` | Numeric; `Group=` requires `User=` |
| `UserNS=` | `--userns` | `keep-id`, `auto`, … |
| `UIDMap=` / `GIDMap=` | `--uidmap` / `--gidmap` | |
| `AddCapability=` / `DropCapability=` | `--cap-add` / `--cap-drop` | |
| `SecurityLabelDisable=` | `--security-opt label=disable` | |
| `NoNewPrivileges=` | `--security-opt no-new-privileges` | |
| `ReadOnly=` / `ReadOnlyTmpfs=` | `--read-only` | `ReadOnlyTmpfs` defaults true |
| `SeccompProfile=` | `--security-opt seccomp=` | or `unconfined` |
| `AppArmor=` | `--security-opt apparmor=` | Arch uses AppArmor |
| `Memory=` / `PidsLimit=` / `Ulimit=` | `--memory` / `--pids-limit` / `--ulimit` | |
| `Sysctl=` | `--sysctl` | |
| `HealthCmd=` / `HealthInterval=` / `HealthOnFailure=` | `--health-*` | `HealthOnFailure=kill` integrates with `Restart=` |
| `AutoUpdate=` | `--label io.containers.autoupdate=…` | See §11 |
| `LogDriver=` / `LogOpt=` | `--log-driver` / `--log-opt` | |
| `Restart=` | — | Actually `[Service] Restart=` |
| `StopSignal=` / `StopTimeout=` | `--stop-signal` / `--stop-timeout` | |
| `ReloadCmd=` / `ReloadSignal=` | — | Adds `ExecReload`; used by `systemctl reload` |
| `Notify=` | `--sdnotify` | `true`/`healthy` for apps that notify systemd |
| `Timezone=` | `--tz` | |
| `PodmanArgs=` | verbatim, before image | Escape hatch for unsupported flags |
| `GlobalArgs=` | verbatim, before `run` | Escape hatch; use sparingly |

Everything else lives in the ordinary systemd sections passed through untouched:
`[Unit]` (`Description=`, `After=`, `Requires=`, `Wants=`, `Before=`), `[Service]`
(`Restart=`, `RestartSec=`, `TimeoutStartSec=`, `ExecStartPre=`), and `[Install]`.

> [!warning] Depend on other Quadlet units by their **generated service** name
> In `[Unit]`, `After=db.container` is translated to `After=db.service`. The full
> man page lists which `[Unit]` keys Quadlet translates between units
> (`Wants`, `Requires`, `Requisite`, `BindsTo`, `PartOf`, `Upholds`, `Conflicts`,
> `Before`, `After`).

### 8. Resources: volumes, networks, pods

Quadlet resolves a reference to another unit's resource **and** adds a dependency on
it. You get a stable name without pre-creating anything by hand.

```ini
# mydata.volume
[Volume]
VolumeName=mydata
Label=purpose=demo
```

```ini
# tor-net.network
[Network]
NetworkName=tor-net
Subnet=172.16.0.0/24
Gateway=172.16.0.1
```

```ini
# app.container — mounts the volume and joins the network
[Container]
Image=nginx:alpine
Volume=mydata.volume:/data
Network=tor-net.network
PublishPort=8080:80
```

```ini
# webapp.pod — a pod several containers join
[Pod]
PodName=webapp
PublishPort=8080:80          # published once, at the pod
```

```ini
# api.container
[Container]
Image=quay.io/example/api:latest
Pod=webapp.pod
```

- `Volume=NAME.volume:/path` → uses `systemd-NAME` (or `VolumeName`) and requires the `.volume` unit.
- `Network=NAME.network` → uses `systemd-NAME` (or `NetworkName`) and requires the `.network` unit.
- `Network=NAME.container` → **reuses another container's network namespace**; combined with `Requires=`/`After=`.
- `Pod=NAME.pod` → joins the pod; takes its network.
- Networks/volumes are oneshot units that ensure the object exists; updating network/volume parameters needs the object removed and the service restarted (or `NetworkDeleteOnStop=true`).

Pods in Quadlet default to `ExitPolicy=stop` and `[Service] Restart=on-failure`, so a
pod whose containers exit cleanly will **not** restart; set `Restart=always` in the
pod's `[Service]` to change that.

### 9. Kubernetes YAML: `.kube`

```ini
# kube-app.kube
[Unit]
Description=Kubernetes YAML app

[Kube]
Yaml=/opt/k8s/deployment.yml
PublishPort=8080:80

[Install]
WantedBy=default.target
```

`Yaml=` is required; `PublishPort=` is merged with ports from the YAML (the unit wins).
`ExitCodePropagation=` controls the service's exit status (`none` is the default).

### 10. Pull and build before run: `.image` / `.build`

Pin an image as a unit, then reference it by the `.image`/`.build` filename:

```ini
# registry-fedora.image
[Image]
Image=registry.fedoraproject.org/fedora:41
AutoUpdate=registry
```

```ini
# app.build
[Build]
ImageTag=localhost/myapp
SetWorkingDirectory=unit          # use the unit file's dir as build context
BuildArg=VERSION=1.0
```

```ini
# app.container
[Container]
Image=app.build                   # uses the image built by app.build
```

Referencing `Image=foo.image` / `Image=foo.build` makes the container service depend on
the corresponding pull/build service.

### 11. Auto-update

`AutoUpdate=registry` labels the container so `podman-auto-update` can pull newer
images and restart the unit:

```ini
[Container]
Image=registry.example.com/app:latest
AutoUpdate=registry
```

```bash
systemctl --user enable --now podman-auto-update.timer   # user-scope timer exists
# or system scope: sudo systemctl enable --now podman-auto-update.timer
```

Requires a fully-qualified image reference. `AutoUpdate=local` restarts when the local
image changes. Both `podman-auto-update.service` and `.timer` ship with Podman.

### 12. Drop-ins

A Quadlet file can be extended without editing it, exactly like systemd:

```
foo.container            # base
foo.container.d/
├── 10-ports.conf        # merged in alphabetical order
└── 20-env.conf
```

Drop-in files have the same format as the base. Dash-truncated directories are also
searched for dashed names (`foo-bar-baz.container` reads `foo-.container.d/`,
`foo-bar-.container.d/`, …), and the top-level `container.d/` applies to all container
units. Verified: two `Environment=` lines from base + drop-in both reach the generated
`ExecStart`.

### 13. Templates

A `foo@.container` generates `foo@.service`, which you instantiate with
`systemctl --user start foo@instance.service`:

```ini
# sleep@.container
[Container]
Image=quay.io/fedora/fedora
Exec=sleep %i

[Install]
WantedBy=default.target
DefaultInstance=100
```

With `DefaultInstance=100`, `sleep@100.service` starts at boot; start others ad hoc.
Per-instance overrides go in `foo@instance.container.d/*.conf`, and an explicit
`foo@instance.container` file also creates that instance. (Whether a *bare instance
drop-in directory* alone instantiates a template is version-dependent — verify with
the dry-run in §14 before relying on it.)

### 14. Debugging and validation

If `systemctl start foo.service` says **`Unit foo.service not found`**, the generator
rejected your file — usually a syntax error or an option newer than your Podman.

```bash
# Print every unit the generator would produce, without touching systemd
/usr/lib/systemd/system-generators/podman-system-generator --user --dryrun

# Arch: the underlying binary, same effect
/usr/lib/podman/quadlet -dryrun -user

# Limit the dry-run to one directory
QUADLET_UNIT_DIRS="$PWD/units" /usr/lib/podman/quadlet -dryrun -user

# Validate an installed unit and its generated result
systemd-analyze --user --generators=true verify foo.service
```

`podman quadlet` also manages installed units:

```bash
podman quadlet list                 # installed quadlets, unit name, state, path
podman quadlet print foo.container  # show a unit's contents
podman quadlet rm foo.container     # remove one
podman quadlet install foo.quadlets # install multiple from a .quadlets bundle
```

## Gotchas

> [!warning] `Unit … not found` almost always means a generator error
> The unit never appears if Quadlet cannot parse it. Run the `--dryrun` generator to
> see the real error instead of guessing. This is the single most common Quadlet
> confusion.

> [!warning] You cannot `systemctl enable` a Quadlet unit
> They are transient/generated. Put `[Install] WantedBy=default.target` in the file.
> Editing `[Install]` also requires `daemon-reload` before it takes effect.

> [!caution] Relative host paths are resolved against the **unit file's directory**
> `Volume=./data:/data` points next to the `.container` file, not your shell's cwd.
> Move the unit and the mount silently follows. Paths starting with `%` are left for
> systemd specifiers — prefix such a path with `./` to force resolution.

> [!warning] Image pulls can exceed systemd's 90-second start timeout
> A first start that pulls a large image can fail with a timeout. Pre-pull, or set a
> longer `[Service] TimeoutStartSec=` (e.g. `900`).

> [!caution] Pods do not auto-restart by default
> Quadlet pods use `ExitPolicy=stop` and `Restart=on-failure`; a clean exit of all
> containers is a success and will not restart. Set `[Service] Restart=always` (and/or
> `ExitPolicy=continue`) if you want the pod to come back.

> [!warning] Naming collisions replace vendor units
> A generated service with the same name as an existing `/usr/` unit replaces it. And a
> pod and a container cannot share a name, so a `PodName=` must not collide with a
> `ContainerName=`.

> [!note] `[Quadlet] DefaultDependencies=` ≠ `[Unit] DefaultDependencies=`
> The `[Quadlet]` one (default `true`) controls the implicit `network-online.target` /
> `podman-user-wait-network-online.service` dependency. The `[Unit]` key of the same
> name is systemd's, with a different meaning.

> [!note] Rootless units ignore `User=`/`DynamicUser=`
> Quadlet refuses to run a unit as a different user via the systemd `[Service]` `User=`.
> To run rootless, put the unit in a rootless search path for that user and, for boot,
> enable lingering.

## Verification

End-to-end check, from the worked example in §4:

```bash
mkdir -p ~/.config/containers/systemd
cat > ~/.config/containers/systemd/hello.container <<'EOF'
[Unit]
Description=Hello Alpine Container

[Container]
Image=alpine
Exec=echo Hello from Quadlet!

[Install]
WantedBy=default.target
EOF

# 1. The generator accepts the file and emits a service
/usr/lib/podman/quadlet -dryrun -user | grep -A2 'hello.service'

# 2. systemd sees a generated unit
systemctl --user daemon-reload
systemctl --user list-unit-files hello.service     # -> generated

# 3. It runs
systemctl --user start hello.service
journalctl --user -u hello.service                 # -> "Hello from Quadlet!"
podman quadlet list | grep hello                   # -> active/exited, path shown
```

Expected: `list-unit-files` shows `hello.service  generated`; because `Exec=` is a
one-shot `echo`, the service finishes (state `exited`) and the log line appears.
`systemctl --user is-enabled hello.service` prints `generated`, and `enable` fails —
both expected.

## Related

- [[podlet-compose-to-quadlet]] — generating these units from a `compose.yaml` with `podlet`
- [[podman-registries]] — so short image names in `Image=` resolve
- [[container-registries]] — where those images come from
- [[tor]] — a container sidecar that becomes a clean `[Container]` unit here
- [[arch-setup]] — `podman` is part of the baseline package list

## Sources

- [podman-systemd.unit(5)](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html) — unit types, search paths, `[Container]`/`[Pod]`/`[Volume]`/`[Network]`/`[Kube]`/`[Image]`/`[Build]`/`[Artifact]` keys, templates, drop-ins, debugging, examples
- [podman-quadlet-basic-usage(7)](https://docs.podman.io/en/latest/markdown/podman-quadlet-basic-usage.7.html) — step-by-step worked examples, rootless/rootful placement, the "cannot be enabled" note
- [podman-quadlet-install(1)](https://docs.podman.io/en/stable/markdown/podman-quadlet-install.1.html) — `podman quadlet install`, `.quadlets` bundles
- [Arch Wiki — Podman § Quadlet](https://wiki.archlinux.org/title/Podman#Quadlet) — Arch paths, `/usr/lib/podman/quadlet -dryrun -user`, lingering, Syncthing example

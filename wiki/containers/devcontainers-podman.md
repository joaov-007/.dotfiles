---
title: "Devcontainers with Podman on Arch Linux"
aliases:
  - Devcontainers
  - Dev Container CLI
  - devcontainer.json
  - "@devcontainers/cli"
  - devcontainer-cli
description: >-
  Install and drive the Dev Container CLI on Arch Linux with rootless Podman: the
  package set, socket-based DOCKER_HOST wiring, a minimal devcontainer.json, the
  up/exec/cleanup lifecycle, Features and their lockfile, editor integration, and the
  version-specific traps — argument ordering, the missing down/stop verbs, and what a
  container can actually see of the host.
tags:
  - containers
  - podman
  - docker
  - devcontainer
  - development
  - arch-linux
  - setup
  - cli
type: guide
status: evergreen
created: 2026-10-17
updated: 2026-10-17
last_reviewed: 2026-10-17
review_after: 2027-04-17
language: en
audience: devops
scope: installing and running Dev Container CLI devcontainers on rootless Podman under Arch Linux
platform:
  - Linux
  - Arch Linux
  - Podman
keywords:
  - devcontainer
  - devcontainer.json
  - devcontainer-lock.json
  - dev container CLI
  - podman-docker
  - DOCKER_HOST
  - podman.socket
  - rootless containers
  - keep-id
  - userns
  - AUR
  - VS Code
sources:
  - "[Arch Wiki — Podman](https://wiki.archlinux.org/title/Podman)"
  - "[devcontainers/cli (GitHub)](https://github.com/devcontainers/cli)"
  - "[containers.dev — Supporting tools](https://containers.dev/supporting)"
  - "[Dev Container CLI — VS Code docs](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli)"
  - "[devcontainer.json reference](https://containers.dev/implementors/json_reference/)"
  - "[podman-system-service(1)](https://man.archlinux.org/man/podman-system-service.1)"
  - "[AUR — devcontainer-cli](https://aur.archlinux.org/packages/devcontainer-cli)"
source_retrieved: 2026-10-17
related:
  - "[[Home]]"
  - "[[quadlet]]"
  - "[[podman-registries]]"
  - "[[container-registries]]"
  - "[[arch-setup]]"
  - "[[dnscrypt-proxy-podman]]"
cssclasses:
  - nota-longa
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Create a teaching guide for installing the Dev Container CLI and setting it up for developer use on Arch Linux with rootless Podman"
ai-review: pending
---

# Devcontainers with Podman on Arch Linux

> [!summary] Containers as a reproducible dev environment
> A **devcontainer** is a `.devcontainer/devcontainer.json` plus a CLI that acts on it. On Arch
> the whole stack is three packages — `podman`, `podman-docker`, `podman-compose` — and with
> `podman-docker` the `devcontainer` CLI works with **no runtime configuration at all**, because
> `/usr/bin/docker` already *is* Podman. `devcontainer up` creates and starts the container and
> runs lifecycle hooks; `devcontainer exec` gets you a shell inside it. Two traps cost the most
> time: `--docker-path` placed *before* the subcommand silently breaks `exec`, and this CLI build
> has no `down` or `stop` verb, so removal goes through `podman` directly.

## Context

You already have rootless Podman on Arch. The reason to add a devcontainer layer on top is
reproducibility: compiler versions, language runtimes, database clients and editor tooling get
described once in a file that is committed next to the code, instead of living in a README that
rots. `docker build` + `docker run` cannot express that — the Dev Container spec adds Features
(composable tooling installers), lifecycle hooks, `remoteUser` and user-env probing on top of the
plain container.

The CLI is Microsoft's **reference implementation** of the spec, so it is the thing VS Code and
Codespaces themselves use. Feature parity with the Docker path is the point: same
`devcontainer.json`, same Features, same `postCreateCommand` semantics. The only differences on
Podman are the ones catalogued under [Gotchas](#gotchas).

Verified on: Arch Linux, `podman` 6.1.4, `podman-docker` 6.1.4, `podman-compose` 1.6.0,
`devcontainer-cli` 0.89.0, rootless Podman with `crun`.

## Details

### 1. Install the container stack

```bash
sudo pacman -S --needed podman podman-docker podman-compose
```

| Package | Role | Pulls in |
|---|---|---|
| `podman` | the engine | `oci-runtime` (crun), `passt` (rootless networking), `containers-common`, `nftables` |
| `podman-docker` | ships `/usr/bin/docker` as a thin Podman emulation shim | `podman`, `sh` |
| `podman-compose` | Compose support, needed only for Compose-based `devcontainer.json` | `podman`, `python`, `python-dotenv`, `python-yaml` |
| `buildah` | optional standalone image-building CLI; `podman build` does not require it | — |

`podman-docker` is the load-bearing one. The devcontainer CLI shells out to a `docker` binary; this
package makes that binary resolve to Podman, which is why no `--docker-path` is needed anywhere
below. It prints `Emulate Docker CLI using podman.` on each use; silence that with an empty
`/etc/containers/nodocker` if it annoys you.

> [!info] Do not install `docker`
> Arch's `docker` package conflicts with `podman-docker`. Installing both is the usual way to end
> up with a real daemon fighting the shim for `/usr/bin/docker`.

### 2. Expose the Podman API socket

Rootless Podman is socket-activated per user; enable it so Docker-API clients (the CLI's own
probes, `podman-compose`, Testcontainers) can connect without a daemon:

```bash
systemctl --user enable --now podman.socket
loginctl enable-linger "$USER"
```

Then point Docker-API clients at it — `~/.config/environment.d/podman.conf`:

```ini
# Point Docker-API clients at the rootless Podman service instead of a daemon.
# ${XDG_RUNTIME_DIR} expansion works here; systemd specifiers like %t do not.
DOCKER_HOST=unix://${XDG_RUNTIME_DIR}/podman/podman.sock
```

`environment.d` is read by the systemd user manager, so it covers GUI apps and user services, and
takes effect at next login. For the current shell session add the same `export` to your shell's
environment file.

> [!note] `DOCKER_HOST` is optional with the shim
> With `podman-docker` installed, the CLI reaches Podman regardless. Set `DOCKER_HOST` anyway for
> everything else that speaks the Docker API. It is a *host-side* connection — never mount that
> socket into a container (see §8).

### 3. Install the devcontainer CLI

Arch route (what this host uses):

```bash
yay -S devcontainer-cli
```

That installs `/usr/bin/devcontainer` (with a `/usr/sbin/devcontainer` symlink) pointing at
`/usr/lib/node_modules/@devcontainers/cli/devcontainer.js`.

No-AUR route, via the Node version manager already in use:

```bash
mise use -g npm:@devcontainers/cli
# or: npm install -g @devcontainers/cli
```

### 4. A minimal `devcontainer.json`

Create `.devcontainer/devcontainer.json` (there is also a `.devcontainer.json` at the repo root —
pick one, don't use both):

```json
{
  "name": "hello-devcontainer",
  "image": "docker.io/library/debian:bookworm-slim",
  "remoteUser": "root",
  "postCreateCommand": "echo hello from $(id -un) on $(uname -m)"
}
```

| Key | Why it is here |
|---|---|
| `image` | pull a base instead of building. Swap for `build.dockerfile` when you need a custom base |
| `remoteUser` | the user `exec` and lifecycle hooks run as |
| `postCreateCommand` | runs once on first create — the hook that proves the CLI lifecycle fired |

`remoteUser: "root"` is deliberate under rootless Podman: with the default user-namespace mapping,
container `root` maps to *your* host UID, so the bind-mounted workspace stays writable. The
alternative — a `vscode`-style UID 1000 user in the image — needs `--userns=keep-id` to line the
mappings up, or the mount shows up owned by a subordinate UID.

Other keys worth knowing: `features` (§6), `mounts`, `containerEnv`, `forwardPorts`,
`updateContentCommand`, `postStartCommand`, and `runArgs` (§8).

### 5. Lifecycle: create, enter, check, clean up

```bash
cd ~/Projects/myproject

devcontainer up --workspace-folder .          # create/start + run lifecycle
devcontainer exec --workspace-folder . bash    # this is "getting in"
```

`up` prints a JSON result line with the outcome and container id. `exec` drops you in as
`remoteUser`, with `cwd` at the workspace folder. For a one-off command, use `--` when the command
takes its own flags, otherwise yargs eats them:

```bash
devcontainer exec --workspace-folder . -- bash -lc 'id; pwd; echo ok'
```

Recreate after editing the config:

```bash
devcontainer up --remove-existing-container --workspace-folder .
```

**There is no `down` and no `stop` in 0.89.0.** The VS Code docs list them; this build does not
have them, and for a single-container config there is nothing to compose down anyway. Removal is
`up --remove-existing-container`, or raw Podman. Every container the CLI creates carries the label
`devcontainer.local_folder`, which makes scoped cleanup safe:

```bash
podman ps -a --filter label=devcontainer.local_folder \
  --format '{{.ID}} {{.Names}} {{.Status}}'

podman rm -f -v \
  $(podman ps -aq --filter label=devcontainer.local_folder=/home/joaov/Projects/myproject)
```

`-v` also reaps the anonymous data volumes the CLI creates. `devcontainer build` only builds the
image; `devcontainer read-configuration` prints the resolved configuration when something does not
behave as written.

### 6. Features and the lockfile

Features are composable tooling installers pulled as OCI artifacts from `ghcr.io`. Add this
`features` key to your `devcontainer.json`:

```json
"features": {
  "ghcr.io/devcontainers/features/common-utils:2": {}
}
```

This is the capability `docker run` has no equivalent for: the CLI installs each Feature into a
derived layer, so `git`, `zsh`, `gh` or a language runtime arrive without hand-writing a
Dockerfile.

The **lockfile** pins the exact resolved version and digest of every Feature. In 0.89.0 generation
is *on by default* (`--no-lockfile` turns it off), so:

```bash
devcontainer up --workspace-folder .     # writes .devcontainer/devcontainer-lock.json
```

Real output of that command on a config using `common-utils:2` — note there is no free-floating
version range left to drift, only digests:

```json
{
  "features": {
    "ghcr.io/devcontainers/features/common-utils:2": {
      "version": "2.7.1",
      "resolved": "ghcr.io/devcontainers/features/common-utils@sha256:e76a6a8a35d1ad824daad1540725e0ec9f8ed2dc00d2850e990a9830013c7d08",
      "integrity": "sha256:e76a6a8a35d1ad824daad1540725e0ec9f8ed2dc00d2850e990a9830013c7d08"
    }
  }
}
```

Then commit it. In CI, make drift fatal instead of silently accepting it:

```bash
devcontainer up --frozen-lockfile --workspace-folder .
devcontainer build --frozen-lockfile .
```

Review and bump:

```bash
devcontainer outdated --workspace-folder .      # current vs available
devcontainer upgrade --dry-run                  # print the new lockfile
devcontainer upgrade                            # write it
```

> [!warning] No `features`, no lockfile
> The lockfile exists to pin Features. A config with only `image` — like §4 — produces no
> `devcontainer-lock.json` at all. That is correct, not a failure: `--frozen-lockfile` in CI will
> fail on such a project unless you add a Feature first.
> `--no-lockfile` and `--frozen-lockfile` are the only lockfile flags, and both exist only on
> `up` and `build`.

### 7. Editor integration

VS Code / VSCodium, with the **Dev Containers** extension: because `/usr/bin/docker` is the
`podman-docker` shim, the default `dev.containers.dockerPath` already works. If you installed
`docker` elsewhere, set `dev.containers.dockerPath` to `podman`. Then either **Reopen in
Container** or **Attach to Running Container** to grab one the CLI started.

Without any extension, the CLI is the whole workflow — `up`, `exec`, and your editor inside the
container. That is the point of the reference implementation: it does not require an IDE.

### 8. What the container can see of the host

A container does **not** see your drive. It sees the image's own rootfs plus exactly the paths
mounted into it. Measured inside a devcontainer created with the §4 config:

| Check | Observed | Why it matters |
|---|---|---|
| Host paths mounted | only the workspace folder | the workspace bind is the entire exposure |
| `/home` inside | empty | your home directory is not there |
| Visible processes | container-only | private PID namespace |
| Podman socket inside | absent | no trivial root-on-host escape |
| `uid_map` | `0 → 1000`, `1 → 100000 65536` | container root **is** your unprivileged user |
| `Seccomp` | `2`, one filter | default syscall filter active |
| `Privileged` | `false` | — |
| `NoNewPrivs` | `0` | **off by default** — the one worth changing |

Audit any container, including ones you did not create:

```bash
podman exec <id> cat /proc/mounts                 # every visible host path
podman exec <id> cat /proc/self/uid_map           # who "root" really is
podman exec <id> grep Seccomp /proc/self/status   # syscall filter
podman inspect <id> --format '{{.HostConfig.Privileged}} {{.HostConfig.CapAdd}}'
```

For a dev container you install packages in, add this `runArgs` array to `devcontainer.json`:

```json
"runArgs": [
  "--security-opt", "no-new-privileges",
  "--cap-drop", "MKNOD",
  "--cap-drop", "NET_RAW",
  "--cap-drop", "AUDIT_WRITE",
  "--cap-drop", "SETPCAP",
  "--ipc", "private",
  "--pids-limit", "512"
]
```

Those drops keep `CHOWN`, `DAC_OVERRIDE`, `FOWNER`, `SETUID/SETGID` and `SETFCAP`, so `apt`/`pacman`
inside the container still work. `--ipc private` is stricter than Podman's default `shareable`.
For code you do not trust, go further — `--cap-drop=ALL`, `--read-only` with `--tmpfs /tmp`,
`--network=none` — and expect to rebuild your dev loop around it.

> [!danger] Never mount the Podman socket into a container
> `-v /run/user/1000/podman/podman.sock:...` is root-equivalent on the host — a full escape, not a
> sandbox. Keep `DOCKER_HOST` a host-side setting.

Containers share the host kernel. Rootless plus userns plus seccomp plus cap-drops is
defence-in-depth against a compromised process, not a boundary against a kernel exploit. For a
real boundary use a sandboxed runtime (`--runtime runsc` for gVisor, `--runtime kata` for Kata
Containers); neither ships with Arch's `podman`, and both are a separate setup.

## Gotchas

> [!important] `--docker-path` before the subcommand silently breaks `exec`
> This is the trap that wastes an afternoon. With `devcontainer --docker-path podman exec
> --workspace-folder . bash`, the string `exec` is taken as the *command to run inside the
> container* instead of as the subcommand, so Podman ends up running a binary literally named
> `exec`:
>
> ```
> crun: executable file `exec` not found in $PATH
> ```
>
> The argv it actually built, captured with a `podman` shim:
>
> ```
> podman exec -i -u root -e ... -w /workspaces/devcontainer <id> exec
> ```
>
> Two working forms — prefer the first, since the shim makes the flag unnecessary:
>
> ```bash
> devcontainer exec --workspace-folder . bash
> devcontainer exec --docker-path podman --workspace-folder . bash   # flag AFTER the subcommand
> ```
>
> The same class of bug hits command flags: `devcontainer exec ... bash -lc '...'` fails with
> `Unknown arguments: l, c`. Insert `--` before the command.

> [!warning] `--mount-workspace-git-root` is on by default
> Launching from a subdirectory of a git repo mounts the **git root**, not your subdirectory. Do
> not start devcontainers from `~`, `~/Projects`, or anywhere with secrets above the project.

> [!caution] Slim images have no `zsh`
> `debian:bookworm-slim` ships `bash` and not `zsh`; asking for `zsh` fails with a different
> `executable file` error. Install it via a Feature or use `bash`.

> [!note] SELinux advice does not apply on Arch
> Arch has no SELinux, so the `:Z` / `relabel=private` mount flags are no-ops and Podman sets
> `label=disable` automatically. AppArmor is enabled on the host but Podman attaches no profile by
> default. Do not copy SELinux hardening advice from Fedora guides here.

> [!warning] Don't reach for `podman system prune`
> It takes out unrelated containers and volumes on the same host. Scope deletions with
> `--filter label=devcontainer.local_folder`, and never run `sudo podman` — that discards the
> user-namespace isolation this setup depends on.

## Verification

```bash
# 1. Stack present
pacman -Qo /usr/bin/docker          # owned by podman-docker
podman info --format '{{.Host.Security.Rootless}}'   # true

# 2. Socket live and answering the Docker API
systemctl --user is-active podman.socket             # active
ls -l "${XDG_RUNTIME_DIR}/podman/podman.sock"
curl -s --unix-socket "${XDG_RUNTIME_DIR}/podman/podman.sock" http://d/_ping   # OK

# 3. CLI present
devcontainer --version

# 4. End to end
cd ~/Projects/myproject
devcontainer up --workspace-folder .                 # JSON line with "outcome":"success"
devcontainer exec --workspace-folder . -- bash -lc 'id -un; pwd'
#   expect: root   /workspaces/myproject
podman ps --filter label=devcontainer.local_folder   # the container, labeled
```

Expected end state: `root` printing from inside, `pwd` showing `/workspaces/<project>`, and
`podman ps` listing the container under the `devcontainer.local_folder` label. To undo everything:
`podman rm -f -v <id>`; the base image stays cached and can be dropped with `podman rmi`.

## Related

The container lifecycle here is the same one [[quadlet]] formalises for long-running services —
use Quadlet when it should survive reboots, and devcontainers when it should not. Registry and
unqualified-image behaviour comes from [[podman-registries]] and [[container-registries]]; a
podman-composed service stack similar to a Compose devcontainer is documented in
[[dnscrypt-proxy-podman]], and the host package baseline in [[arch-setup]].

## Sources

- [Arch Wiki — Podman](https://wiki.archlinux.org/title/Podman) — package set, rootless model, the `Podman#Docker` shim section; authoritative.
- [devcontainers/cli](https://github.com/devcontainers/cli) — reference implementation, Feature resolution and lockfile semantics; authoritative.
- [containers.dev — Supporting tools](https://containers.dev/supporting) — spec status and which tools implement it; authoritative.
- [Dev Container CLI — VS Code docs](https://code.visualstudio.com/docs/devcontainers/devcontainer-cli) — command reference; note that `stop`/`down` listed there are absent from 0.89.0.
- [devcontainer.json reference](https://containers.dev/implementors/json_reference/) — property schema for `image`, `build`, `remoteUser`, `features`, `runArgs`; authoritative.
- [podman-system-service(1)](https://man.archlinux.org/man/podman-system-service.1) — socket activation and `DOCKER_HOST`; man page.
- [AUR — devcontainer-cli](https://aur.archlinux.org/packages/devcontainer-cli) — the Arch package used above; review the PKGBUILD before building.

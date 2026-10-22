# Scripts

Every script lives under `scripts/`, grouped by what it does. `scripts/`
is blacklisted in `.stow-local-ignore`, so nothing in it is ever linked
into `$HOME`.

All of them are `#!/usr/bin/env bash` with `set -Eeuo pipefail`, and all
of them answer `-h` / `--help`.

## `scripts/stow/stow.sh`

Links the packages into a target directory, honouring the blacklist in
`.stow-local-ignore`.

```
Usage: stow.sh [OPTIONS] PACKAGE [PACKAGE...]

  -t, --target DIR   Target directory (default: $HOME)
  -n, --dry-run      Show what would be done, change nothing
  -v, --verbose      Verbose stow output
  -u, --unstow       Remove the links instead of creating them
  -a, --adopt       Adopt existing files that would conflict
  -g, --global-ignore  Link ~/.stow-global-ignore to the blacklist and exit
  -h, --help         Show this help
```

### Why it exists

Stow reads `.stow-local-ignore` only at the root of the package it is
stowing. That covers `stow -t ~ .`, where the whole repository is the
package, but not `stow -t ~ neovim`, where each package is stowed on its
own.

The script parses the blacklist itself and passes every pattern to Stow
as `--ignore`, so both paths behave the same. It also refuses to stow a
blacklisted package by name.

It reproduces Stow's own parsing rules: a `#` starts a comment when it is
at the beginning of a line or preceded by a space, `\#` is a literal `#`.
A pattern without a `/` matches a path segment at any depth, so `nixos`
blacklists the directory anywhere. A pattern with a `/` is matched
against the path relative to the package root.

### Examples

```sh
# link one package
./scripts/stow/stow.sh neovim

# link several
./scripts/stow/stow.sh zsh neovim git mise

# see what would happen
./scripts/stow/stow.sh --dry-run zsh

# take over the files that are already there
./scripts/stow/stow.sh --adopt neovim

# remove the links
./scripts/stow/stow.sh --unstow zsh

# make plain "stow" honour the blacklist too
./scripts/stow/stow.sh --global-ignore
```

### `--adopt`

Stow refuses to overwrite a real file with a symlink. `--adopt` moves the
existing file into the package and puts the symlink in its place, which
is the way to take over a configuration that is already in `$HOME`:

```sh
./scripts/stow/stow.sh --adopt zsh
```

The content is preserved, and it ends up tracked in the repository.

### `--global-ignore`

Stow reads `~/.stow-global-ignore` for every package that has no local
ignore file. Linking the repository's blacklist there means a plain
`stow -t ~ neovim` honours it as well:

```sh
./scripts/stow/stow.sh --global-ignore
```

## `scripts/git/set-collections-git.sh`

Applies a set of git settings.

```
Usage: set-collections-git.sh [OPTIONS]

  --global          Use global git config (default)
  --local           Use repository config
  --system          Use system config
  -n, --dry-run     Show changes without applying them
  -v, --verbose     Show extra information
  -h, --help        Show this help
```

The settings keep the history linear:

| Setting | Value |
| --- | --- |
| `branch.autosetuprebase` | `always` |
| `fetch.prune` | `true` |
| `pull.default` | `current` |
| `pull.rebase` | `true` |
| `push.autoSetupRemote` | `true` |
| `push.default` | `current` |
| `rebase.autoSquash` | `true` |
| `rebase.autoStash` | `true` |
| `rebase.stat` | `true` |
| `rerere.autoUpdate` | `true` |
| `rerere.enabled` | `true` |
| `diff.submodule` | `log` |

The script exists for the machine before home-manager is available. Once
NixOS manages the git configuration, it is redundant there — the same
values live in `nixos/modules/home/config/git.nix`.

A value of `unset` removes the key instead of setting it.

## `scripts/nixos/test-all.sh`

Builds every check in the flake.

```
Usage: test-all.sh [SYSTEM]

SYSTEM defaults to x86_64-linux
```

It builds `checks.<system>.<name>` for each of the checks and prints a
line per check. It exits with the number of failures, so it drops
straight into CI:

```sh
./scripts/nixos/test-all.sh
./scripts/nixos/test-all.sh aarch64-linux
```

The list of checks is described in [nixos.md](nixos.md#the-checks).

## `scripts/unbound/executable_get_unbound_adblock.sh`

Generates the unbound block lists.

It fetches the advertising and tracking lists, converts the hosts and the
adblock rules into `local-zone` entries with `always_null`, and writes the
result to `/etc/unbound/unbound.conf.d/_unbound-adhosts.conf`.

Before installing, it keeps a timestamped copy of the previous file:

```
/etc/unbound/unbound.conf.d/_unbound-adhosts.conf.2026-10-22T11:30
```

At the end it checks the configuration with `unbound-checkconf` and
restarts the service.

### Requirements

`curl`, `perl`, `python3` with the `tld` module, `unbound`, and root.

The `tld` module is not in the distribution repositories on every
release, and the script installs it with `pip` when it is missing.

### Sources

| List | What it blocks |
| --- | --- |
| `easylist`, `easyprivacy` | Advertising and tracking |
| `fanboy`, `fanboy-annoyance` | Social and "annoyance" lists |
| `oisd` | The combined open list |
| `adaway`, `pihole` | Hosts-format blocking lists |
| `stevenblack` | The unified hosts list |
| `doh` | The known DNS-over-HTTPS resolvers |
| `dshield` | The low, medium and high threat feeds |
| `yoyo` | The list used by the browser extension |

The script also merges in `/etc/adblack.txt`, a personal list, when it
exists. That file is not in the repository.

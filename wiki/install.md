# Installing on a new machine

The repository is distribution-agnostic on purpose. Nothing in it depends
on Arch, Debian or NixOS except the two places that say so out loud: the
system package list in [packages.md](packages.md), and the `/etc` mirror
described in [system.md](system.md).

Everything else — zsh, Neovim, git, mise, the editor and shell plugins —
is a plain file that lands in the same place on every distribution.

## Requirements

| Tool | Why | Where it comes from |
| --- | --- | --- |
| `git` | Cloning the repository | The distribution |
| `stow` | Linking the packages | The distribution (`pacman -S stow`) |
| `mise` | Pinning the tool versions | [mise.run](https://mise.jdx.dev/getting-started.html) |
| `zsh` | The shell | The distribution |

## Steps

### 1. Clone

```sh
git clone git@github.com:joaov-007/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles
```

### 2. Install Stow and mise

```sh
# Arch
sudo pacman -S --needed stow git

# Debian / Ubuntu
sudo apt-get install -y stow git
```

mise installs itself, and it is the same on every distribution:

```sh
curl https://mise.run | sh
```

The installer writes to `~/.local/bin/mise`. Make sure that directory is on
`PATH`:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### 3. Link the packages

```sh
./scripts/stow/stow.sh zsh neovim git mise curl aria2 w3m halloy espanso \
    gammastep geoclue chromium-flags brave-flags code-flags electron-flags
```

Or one at a time while iterating — the symlinks point straight at the
working tree, so there is nothing to re-run after an edit:

```sh
./scripts/stow/stow.sh zsh
```

To see what a command would do without touching anything:

```sh
./scripts/stow/stow.sh --dry-run zsh
```

To make plain `stow` calls honour the blacklist as well:

```sh
./scripts/stow/stow.sh --global-ignore
```

### 4. Install the system packages

The dotfiles assume a set of binaries that the distribution provides. See
[packages.md](packages.md) for the list and the per-distribution install
commands.

### 5. `/etc`, only if you want it

The `etc/` package mirrors the system configuration and needs root:

```sh
sudo stow -t /etc etc
```

This is optional and it is the one part of the repository that is
Arch-specific. Read [system.md](system.md) before running it — it
overwrites `unbound`, `clamav` and `geoclue` configuration.

### 6. Start a shell

```sh
exec zsh
```

`~/.zshenv` points `ZDOTDIR` at `~/.config/zsh`, and the numbered files
there are sourced in order. If something is wrong, `~/.config/zsh/README.md`
has a troubleshooting section.

## Verifying

```sh
# the links exist and point into the repository
find ~/.config -maxdepth 1 -type l -exec ls -la {} \;

# the shell starts cleanly
zsh -i -c 'echo $ZDOTDIR'

# the tool versions resolved
mise current

# a full stow report, without changing anything
./scripts/stow/stow.sh --dry-run --verbose zsh neovim
```

## Uninstalling

```sh
./scripts/stow/stow.sh --unstow zsh neovim git mise
sudo stow -D -t /etc etc
```

Stow removes only the links it created. The files stay in the repository.

## Moving to another distribution

Nothing has to change. Clone, install `stow`, run the same
`scripts/stow/stow.sh` command. The only difference is step 4 — the system
packages come from a different package manager — and step 5, which is
skipped on anything that is not Arch.

The `ZDOTDIR` path, the XDG directories and every plugin path are derived
from `$HOME` at runtime, so the same files work under a different user
name and a different home directory.

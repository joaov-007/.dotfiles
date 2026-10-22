# Layout

## The repository

```
~/.dotfiles/
├── .stow-local-ignore   # blacklist: what is never linked into $HOME
├── .gitignore
├── README.md            # short orientation, points here
├── TODO.md              # what is next
│
├── aria2/               # stow packages, one per tool
├── brave-flags/
├── chromium-flags/
├── code-flags/
├── curl/
├── electron-flags/
├── espanso/
├── gammastep/
├── geoclue/
├── git/
├── halloy/
├── mise/
├── neovim/
├── niri/
├── rclone-services/
├── w3m/
├── zsh/
│
├── etc/                 # NOT a package: mirrors /etc
├── nixos/               # NOT a package: the NixOS flake
├── scripts/             # NOT a package: repository tooling
└── wiki/                # NOT a package: this documentation
```

## The Stow model

A Stow *package* is a directory whose contents mirror the tree it installs
into the target. `neovim/.config/nvim/init.lua` becomes
`~/.config/nvim/init.lua`, so the repository shows the target layout
verbatim rather than a stow-specific one.

Stowing one package:

```sh
stow -t ~ neovim
```

creates `~/.config/nvim` as a symlink into the repository. The symlink is
relative, which keeps the repository movable:

```
~/.config/nvim -> ../../.dotfiles/neovim/.config/nvim
```

Because the link points at the working tree, an edit in the repository is
live immediately. There is no copy step and no "apply" step — the only
thing that needs re-running is `stow` itself, and only when a *new* file
appears that was not there when the link was made.

### Stow's folding rule

Stow walks the package and creates the shallowest symlink it can. If
`~/.config` already exists, it descends into it and links `~/.config/nvim`
as a whole. If `~/.config` does **not** exist, it links `~/.config` itself
and every app directory ends up inside the repository.

That second case is the classic Stow trap. `scripts/stow/stow.sh` avoids it
by requiring the packages to be named explicitly, and by linking
`~/.stow-global-ignore` so that plain `stow` calls honour the blacklist
too.

## Package map

What each package actually installs, verified by running Stow against a
scratch target:

| Package | Installs |
| --- | --- |
| `aria2` | `~/.config/aria2` |
| `brave-flags` | `~/.config/brave-flags.conf` |
| `chromium-flags` | `~/.config/chromium-flags.conf` |
| `code-flags` | `~/.config/code-flags.conf` |
| `curl` | `~/.curlrc` |
| `electron-flags` | `~/.config/electron-flags.conf` |
| `espanso` | `~/.config/espanso` |
| `gammastep` | `~/.config/gammastep` |
| `geoclue` | `~/.config/geoclue.conf` |
| `git` | `~/.config/git` |
| `halloy` | `~/.config/halloy` |
| `mise` | `~/.config/mise` |
| `neovim` | `~/.config/nvim` |
| `niri` | `~/.config/niri` |
| `rclone-services` | `~/rclone@egdrive.service` — see [system.md](system.md) |
| `w3m` | `~/.config/w3m` |
| `zsh` | `~/.zshenv`, `~/.zshrc`, `~/.config/zsh` |

`rclone-services` is the odd one out: it installs the unit at the top of
the home directory instead of under `~/.config/systemd/user/`, so systemd
never picks it up. The fix is a directory level — see
[system.md](system.md#rclone-services).

## The blacklist

`.stow-local-ignore` at the repository root lists what must never be
linked into `$HOME`:

| Entry | Reason |
| --- | --- |
| `nixos` | System configuration built by `nixos-rebuild`, not a dotfile |
| `scripts` | Repository tooling, not a dotfile |
| `etc` | Belongs in `/etc`, installed with `sudo stow -t /etc etc` |
| `zsh.old` | Leftover from the previous zsh layout |
| `wiki` | Documentation, read in the browser rather than linked |
| `^/TODO\.md$` | The task list, for the same reason |

Stow reads that file only at the root of the package it is stowing, which
means it applies when the whole repository is the package
(`stow -t ~ .`) and not when a single package is stowed on its own.
`scripts/stow/stow.sh` parses the same file and passes the patterns to
every Stow call as `--ignore`, so both paths behave the same.

The file also replaces Stow's built-in ignore list, so the defaults worth
keeping are repeated at the bottom of it.

## Not packages

| Directory | What it is | How it is applied |
| --- | --- | --- |
| `nixos/` | A NixOS flake with a dendritic module tree | `sudo nixos-rebuild switch --flake ./nixos#bacon` |
| `etc/` | A mirror of `/etc` | `sudo stow -t /etc etc` |
| `scripts/` | Repository tooling | Run by hand |

## Branches and worktrees

| Branch | Worktree | Purpose |
| --- | --- | --- |
| `dev` | `~/.dotfiles` | The main line |
| `feat/zsh-polish` | `~/.dotfiles-worktrees/zsh-config` | Shell rework |
| `feat/nvchad-modernize` | `~/.dotfiles-worktrees/nvchad-modernize` | Neovim rework |
| `cleanup/remove-chezmoi-config` | `~/.dotfiles-worktrees/chezmoi-cleanup` | Removing the chezmoi leftovers |

`nixos/` was a separate repository (`nixos-config`) before it became a
subtree here. The history was preserved with a merge of unrelated
histories, so `git log nixos/` still shows the original commits.

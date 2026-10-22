# Dotfiles wiki

Documentation for this repository. It lives inside the repo on purpose: the
wiki is versioned with the code it describes, works offline, and is stowable
like everything else.

## Pages

| Page | What it covers |
| --- | --- |
| [layout.md](layout.md) | The repository map and how the Stow model fits together |
| [install.md](install.md) | Setting up a new machine, Arch and other distributions |
| [packages.md](packages.md) | mise, tool versions, and system packages per distribution |
| [shell.md](shell.md) | The zsh package: plugins, prompt, history, keybindings |
| [editor.md](editor.md) | The Neovim package: lazy.nvim, NvChad, LSP setup |
| [nixos.md](nixos.md) | The `nixos/` subtree, flakes, and the home-manager integration |
| [system.md](system.md) | The `/etc` mirror, systemd units, unbound, and the security posture |
| [scripts.md](scripts.md) | Every script under `scripts/`, with its options |

## The short version

- One repository, one folder: `~/.dotfiles`.
- Every top-level directory is a [GNU Stow](https://www.gnu.org/software/stow/)
  package. Stowing it creates symlinks under `$HOME`.
- `nixos/`, `scripts/` and `etc/` are **not** packages. `.stow-local-ignore`
  keeps them out.
- [mise](https://mise.jdx.dev) pins the tool versions. The system binaries
  come from the distribution's package manager.
- History is [git](https://git-scm.com). Nothing is generated, nothing is
  copied — the symlinks point straight at the working tree.

## Conventions

- Shell scripts are `#!/usr/bin/env bash` with `set -Eeuo pipefail`, and
  every one of them answers `-h` / `--help`.
- Paths in the repository are relative to the package root, so a package
  mirrors the tree it installs into.
- Comments explain *why*, not *what*.

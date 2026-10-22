# Packages

Two separate things are called "packages" here, and they are installed in
two different ways.

| | Tool versions | System binaries |
| --- | --- | --- |
| Managed by | [mise](https://mise.jdx.dev) | The distribution's package manager |
| Declared in | `mise/.config/mise/config.toml` | [packages.md](#system-binaries), by hand |
| Portable across distributions | Yes | Only if the distribution has a package for it |

## mise

mise pins the version of the tools that have more than one. The config
lives in the `mise/` package and is stowed to `~/.config/mise/config.toml`:

```toml
[tools]
jd = "latest"
node = "latest"
npm = "latest"
```

`05-mise.zsh` evaluates `mise activate zsh`, which puts the shims at the
front of `PATH` and re-resolves the versions when the working directory
changes.

The file holds no comments on purpose. mise rewrites the file when it
changes a pin, and the rewrite drops anything it cannot parse back. The
list is short enough to read at a glance anyway.

Everything else — `fzf`, `zoxide`, `atuin`, `bat`, `eza`, `delta`, `git`,
`nvim` — is a distribution package and is deliberately absent from that
list. A version pin only earns its place when the tool actually has
several versions in use.

To add one:

```sh
mise use --global node@24
```

That rewrites `~/.config/mise/config.toml`, which is the stowed file — the
change lands in the repository because the symlink points there.

## System binaries

These are the binaries the configuration expects. Every one of them is
optional at runtime: the shell checks for the binary and skips the block
if it is missing. Nothing breaks, the feature just does not exist.

### Required

| Tool | Arch package | What it does |
| --- | --- | --- |
| `git` | `git` | Version control, and the git helpers in `80-git.zsh` |
| `zsh` | `zsh` | The shell |
| `stow` | `stow` | Links the packages into `$HOME` |
| `mise` | `mise` | Tool versions |
| `fzf` | `fzf` | Fuzzy finder: Ctrl-R, Ctrl-T, Alt-C |
| `fd` | `fd` | The file list behind the fzf windows |
| `bat` | `bat` | Previews in the fzf menu, and `MANPAGER` |
| `eza` | `eza` | Directory previews in the fzf menu |
| `zoxide` | `zoxide` | `z` jumps to frecent directories |
| `atuin` | `atuin` | Synced history, takes over Ctrl-R |
| `delta` | `git-delta` | Renders the git diff |

### Optional

| Tool | Arch package | What it does |
| --- | --- | --- |
| `rg` | `ripgrep` | Search |
| `tree` | `tree` | Directory trees |
| `nvim` | `neovim` / `neovim-nightly` (AUR) | The editor |
| `alacritty` | `alacritty` | The terminal |
| `w3m` | `w3m` | The terminal browser |
| `rclone` | `rclone` | The sync unit in `rclone-services` |
| `espanso` | `espanso-wayland-git` (AUR) | Text expansion |
| `gammastep` | `gammastep` | Display gamma |
| `halloy` | `halloy` | The IRC client |
| `geoclue` | `geoclue` | The location service |
| `clamav` | `clamav` | The antivirus, with `etc/clamav` |
| `unbound` | `unbound` | The DNS resolver, with `etc/unbound` |

### zsh plugins

zinit installs the plugins, and nothing else. Each one is a no-op when the
binary it wraps is missing.

| Plugin | Source | What it does |
| --- | --- | --- |
| `fast-syntax-highlighting` | `zdharma-continuum` | Colours the command line as you type |
| `zsh-autosuggestions` | `zsh-users` | Fish-style ghost text |
| `fzf-tab` | `Aloxaf` | The Tab key opens an fzf menu |
| `pure` | `sindresorhus` | The prompt |

zinit clones itself to `~/.local/share/zinit/zinit.git` on first run. Update
it with `zinit self-update`.

## Installing them

### Arch

```sh
sudo pacman -S --needed \
  git zsh stow mise \
  fzf fd bat eza git-delta zoxide atuin ripgrep tree \
  alacritty w3m rclone geoclue clamav unbound gammastep halloy

# AUR: neovim-nightly, espanso-wayland-git
paru -S neovim-nightly espanso-wayland-git
```

`zsh-autosuggestions`, `zsh-syntax-highlighting` and `zsh-completions` are
also in the official repositories, but zinit clones the first two itself,
so installing them is optional.

### Debian / Ubuntu

```sh
sudo apt-get install -y \
  git zsh stow \
  fzf fd-find batcat eza git-delta zoxide atuin ripgrep tree \
  alacritty w3m rclone geoclue clamav unbound

# mise, from its own installer
curl https://mise.run | sh
```

Two names differ from Arch: the `fd` binary is `fdfind` on Debian, and
`bat` is `batcat` on releases before Trixie. Either works if the
`FZF_CTRL_T_COMMAND` and `MANPAGER` variables are adjusted.

### NixOS

On NixOS the system is built by the flake, and the packages come from
`modules/home/config/shell.nix`. Nothing needs to be installed by hand:
see [nixos.md](nixos.md).

## Checking what is missing

```sh
for b in git zsh stow mise fzf fd bat eza zoxide atuin delta; do
  command -v "$b" >/dev/null 2>&1 || printf 'missing: %s\n' "$b"
done
```

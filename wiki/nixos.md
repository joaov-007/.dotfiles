# NixOS

`nixos/` is a NixOS configuration built with a flake. It is **not** a
Stow package — `.stow-local-ignore` keeps it out of `$HOME` — and it is
also the one part of the repository that does not install into a home
directory.

It was a separate repository (`nixos-config`) before it became a subtree
here. The history was preserved with a merge of unrelated histories, so
`git log nixos/` still shows the original commits.

## The dendritic pattern

The flake does not list its modules. It uses
[flake-parts](https://flake.parts) together with
[import-tree](https://github.com/denful/import-tree), and every `.nix`
file under `modules/` exports its attributes as `flake.*` automatically.

```
nixos/
├── flake.nix           the inputs, and the import-tree call
├── flake.lock          the pinned inputs
├── modules/
│   ├── parts.nix       flake-parts: systems, formatter, home-manager
│   ├── modules.nix     the third-party module imports
│   ├── attrs/          reusable attributes: desktop, dev, security, yazi
│   ├── system/         core, settings, drivers, audio, fonts, security
│   ├── home/           the home-manager modules
│   ├── hosts/          the per-host definitions
│   └── tests/          the nix build checks
└── scripts/            moved to ../scripts/nixos
```

The layout under `modules/` is the convention:

| Directory | Holds |
| --- | --- |
| `system/` | What the operating system provides |
| `home/` | What the user gets |
| `attrs/` | Reusable bundles, composed by the others |
| `hosts/` | The per-machine definition |
| `tests/` | One file per check, each exporting `checks.<system>.<name>` |

`flake.nix` is three lines of logic:

```nix
outputs = inputs:
  inputs.flake-parts.lib.mkFlake {inherit inputs;}
  (inputs.import-tree ./modules);
```

## Building it

```sh
# rebuild the system
sudo nixos-rebuild switch --flake ./nixos#bacon

# rebuild without switching
sudo nixos-rebuild build --flake ./nixos#bacon

# format the Nix code
nix fmt
```

The host is `bacon`, defined in `modules/hosts/bacon/`. The name is the
last component of `--flake ./nixos#bacon`.

## home-manager

home-manager is integrated as a NixOS module rather than installed
standalone, in `modules/system/settings/home-manager.nix`:

| Setting | Value | Why |
| --- | --- | --- |
| `useGlobalPkgs` | `true` | The home modules use the system package set, so a tool is not installed twice |
| `backupFileExtension` | `backup` | Home-manager keeps a `.backup` copy of anything it overwrites |
| `extraSpecialArgs` | `{inherit self inputs;}` | The modules can reach the flake inputs |
| `sharedModules` | `self.homeModules.default` | The default set is shared by every user |

The home modules are grouped by what they are for:

| Module | Holds |
| --- | --- |
| `user` | The personal identity — currently only `joaov` |
| `global` | `common`, `shell`, `git`, `xdg`, `nvim`, `yazi` |
| `desktop` | `niri`, `noctalia`, `flatpak`, `kdeconnect` |
| `system` | `udiskie`, `syncthing` |
| `default` | All of the above |

## Where NixOS and the dotfiles meet

This is the seam worth understanding, because the two halves do not
overlap as much as they could.

| Concern | On NixOS | On Arch |
| --- | --- | --- |
| Shell config | home-manager | The `zsh/` Stow package |
| Prompt | `starship` (`modules/home/config/shell.nix`) | `pure` (the `zsh/` package) |
| Neovim | `modules/home/apps/nvim.nix` | The `neovim/` Stow package |
| Git | `modules/home/config/git.nix` | The `git/` Stow package |
| Tool versions | nixpkgs | mise |

The two sides currently ship a **different prompt**. On NixOS it is
starship; everywhere else it is `pure`. The same is true of the Neovim
and git configurations.

The eventual answer is to make home-manager the only source for the
files it can manage, and let the Stow packages cover the distributions
that do not have Nix. That work is tracked in `TODO.md`.

Until then, a NixOS machine and an Arch machine are two configurations
that share a repository, not one configuration in two places.

## The checks

`modules/tests/` holds one file per check. Each exports
`checks.<system>.<name>`, and `scripts/nixos/test-all.sh` builds them
all:

```sh
./scripts/nixos/test-all.sh            # x86_64-linux
./scripts/nixos/test-all.sh aarch64-linux
```

| Check | What it asserts |
| --- | --- |
| `aide-integrity` | The AIDE database is in place |
| `apparmor-active` | AppArmor is enforcing |
| `apparmor-not-aggressive` | The profiles are not in complain mode |
| `boot-health` | The boot is healthy |
| `boot-time` | The boot time is within the budget |
| `clamav-scanner` | ClamAV is installed and configured |
| `dns-resolution` | DNS resolves |
| `doas-privilege` | `doas` works |
| `firewall-active` | The firewall is up |
| `kernel-hardening` | The kernel parameters are set |
| `kernel-modules-blacklist` | The blacklist is applied |
| `locale-timezone` | The locale and the timezone are right |
| `package-smoke` | The declared packages are present |
| `security-posture` | The overall posture |
| `user-isolation` | The users are separated |

The script exits with the number of failures, so it drops straight into
CI.

## The import-tree gotcha

`import-tree` only discovers the `.nix` files that git tracks. A new
module that is not committed is invisible to the flake, and the build
fails with a confusing "attribute not found" instead of "file missing".

```sh
git add modules/
sudo nixos-rebuild switch --flake ./nixos#bacon
```

Commit before rebuilding.

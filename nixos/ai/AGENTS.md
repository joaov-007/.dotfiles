# AGENTS.md

Single-host NixOS flake (`bacon`, user `jaov`). home-manager as NixOS module. Secrets via sops-nix (age). Impermanence via preservation (preserves to `/persistent`).

## Build & apply

```bash
sudo nixos-rebuild switch --flake .#bacon   # build + switch (covers both system and home-manager)
nix build .#nixosConfigurations.bacon.config.system.build.toplevel  # build-only dry-run
```

No separate `home-manager switch` needed — home-manager is a NixOS module, rebuilt via `nixos-rebuild`.

## Nix gotchas

- **Uses Lix** (`pkgs.lix`), not CppNix
- **Auto-import**: every `.nix` under `modules/nixos/` is auto-imported (via `default.nix` -> `listFilesRecursive`); same for `modules/home/` (via `home.nix`). Adding a file to either dir is sufficient.
- **Unfree**: `obsidian`, `open-webui` allowed via `nixpkgs.config.allowUnfreePredicate`
- **Formatter**: `nix fmt .` uses `alejandra` (defined in `flake.nix` formatter output)
- **State version**: `25.11` (system and home)
- **hardware-configuration.nix** is auto-generated — never edit
- **`flake.nix`**: 5 inputs (`nixpkgs/nixos-unstable`, preservation, sops-nix, home-manager, neovim-nightly-overlay`)

## Structure

- `modules/hosts/bacon/` — host-specific (configuration.nix, home.nix, hardware-configuration.nix)
- `modules/nixos/` — shared system modules (auto-imported)
- `modules/home/` — home-manager user modules (auto-imported)
- `modules/others/` — config files for external tools (kitty, nvim), symlinked via `home.file`
- `secrets/secrets.yaml` — sops-encrypted; edit with `sops secrets/secrets.yaml`

## Key modules

| Module | What |
|--------|------|
| `nix.nix` | Lix, Nix GC daily (delete >7d), Cachix substituters, nix-ld |
| `preservation.nix` | Persists /var/lib/*, /etc/ssh, etc. to `/persistent` |
| `sops.nix` | sops-nix with age, declares `jaov-password` and `root-password` |
| `gpg.nix` | `programs.gnupg.agent` with SSH support |
| `openwebui.nix` | Open WebUI at 127.0.0.1:8080, connects to local Ollama |
| `dev.nix` (both dirs) | `dev.user.name`/`email` options; set in `configuration.nix`, bridged to home-manager in `home.nix` |
| `git.nix` | Reads `config.dev.user.*`, has an `enable` option (default true) |
| `shell.nix` | bash + blesh + fzf + starship + direnv + zoxide + atuin + custom functions (mkcd, cpmk, .., myip, ports, killport, bak) |
| `cli.nix` | bat, btop, ripgrep, fd, jq, trash-cli, alejandra, LSPs, etc. |
| `nvim.nix` | neovim nightly (from overlay) + pynvim; symlinks `modules/others/nvim` (git submodule) to `~/.config/nvim` |
| `desktop.nix` | kitty + obsidian + calibre; symlinks kitty config from `modules/others/kitty` |

## Quirks

- `programs.firefox.package = pkgs.librewolf` — Firefox is actually LibreWolf
- `services.ollama` runs as a **home-manager user service**, not system-wide
- `hardware.graphics.extraPackages` includes `intel-media-driver` + `vpl-gpu-rt`
- `fonts.packages` uses `nerd-fonts` namespace (fira-code, jetbrains-mono, iosevka, etc.)
- `boot.loader.systemd-boot.configurationLimit = 12` and `boot.tmp.cleanOnBoot = true`
- `system.autoUpgrade` runs at 02:00 daily with 45min random delay
- `modules/others/nvim` is a git submodule (gitignored); `modules/others/kitty` is also a submodule
- `.editorconfig`: 2-space indent for `.nix`, LF, UTF-8

## Secrets

```bash
sops secrets/secrets.yaml                     # edit
nix run nixpkgs#sops -- secrets/secrets.yaml   # or with nix
```



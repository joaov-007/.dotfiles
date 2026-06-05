# Task: Create GNOME NixOS module with option

Created `modules/nixos/gnome.nix` with `dev.desktop.gnome.enable` (default: true).

Updated `modules/hosts/bacon/configuration.nix`:
- Removed raw `services.xserver.enable`, `services.displayManager.gdm.enable`, `services.desktopManager.gnome.enable`
- Replaced with `dev.desktop.gnome.enable = true`

Module is auto-imported via `modules/nixos/default.nix`.

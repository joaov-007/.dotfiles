# TODO List

## Overview

This file tracks tasks and features for the NixOS configuration following the dendritic pattern.

## Short-term Tasks

- [ ] Convert home-manager configuration to features pattern
- [ ] Organize configuration into modules/attrs and modules/features structure
- [ ] Ensure all features are properly exported and can be enabled per system
- [ ] Make use of flake.modules.nixos or home for more reproducible approach
- [ ] Not use bleh for everything I want in nixos bash with nix power

## Medium-term Tasks

- [ ] Add more feature modules following the dendritic pattern
- [ ] Improve build times and caching
- [ ] Document each feature module

## Long-term Tasks

- [ ] Refactor configuration for better maintainability
- [ ] Add CI/CD pipeline for configuration validation
- [ ] Create contribution guidelines

## Features Status

- [x] Git feature module
- [ ] Niri feature module
- [ ] Development tools feature module
- [ ] Security features

## Tool and Dead-Code Cleanup Candidates

Cleanup completed. Comma remains enabled, and preservation must be kept for future use.

### Redundant Installs and Package Setup

- [x] Remove `foot` terminal; Niri shortcuts currently launch Alacritty.
- [x] Remove system `github-cli`; Home Manager already installs/configures `gh`.
- [x] Remove duplicate installations of `btop`, `git`, `neovim`, and `nodejs`.
- [x] Remove duplicate JetBrains Mono Nerd Font installation.
- [x] Remove duplicate `fira-code` entry.
- [x] Remove duplicate `dialout` user-group entry.
- [x] Remove duplicate Intel-driver import and duplicate `mesa`/`vulkan-tools` entries.

### Unused Modules and Configuration

- [x] Keep the `comma` feature enabled through `nixIndexDatabase`.
- [x] Remove the Yazi wrapper, settings, and package.
- [x] Remove unused flake input: `nixos-anywhere`.

### Installed Tools to Review

- [x] Remove `opencode`.
- [x] Remove `herdr`.
- [x] Remove `vulkan-tools`.

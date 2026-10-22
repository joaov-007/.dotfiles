#!/usr/bin/env bash
set -euo pipefail

# Official repo packages
sudo pacman -S --needed --noconfirm \
	alacritty atuin bat clamav delta eza fd fzf gammastep geoclue git \
	mise rclone stow tree unbound w3m zoxide zsh

# AUR packages (requires yay/paru) — review PKGBUILDs first
if command -v paru >/dev/null; then
	paru -S --needed --noconfirm espanso halloy nvim
fi

echo "Done. Install mise tools separately: mise install"

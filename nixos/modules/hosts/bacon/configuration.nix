# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  pkgs,
  config,
  lib,
  inputs,
  ...
}: {
  networking.hostName = "bacon";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Sao_Paulo";

  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  nixpkgs.config.allowUnfreePredicate = pkg:
    builtins.elem (lib.getName pkg) [
      "obsidian"
      "open-webui"
    ];

  nixpkgs.overlays = [inputs.neovim-nightly.overlays.default];

  dev.desktop.gnome.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "altgr-intl";
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    jack.enable = true;
    wireplumber.enable = true;
  };

  users.users.root.hashedPasswordFile = config.sops.secrets."root-password".path;

  users.users.jaov = {
    isNormalUser = true;
    extraGroups = ["wheel" "adm" "audio" "input" "video" "networkmanager"];
    hashedPasswordFile = config.sops.secrets."jaov-password".path;
  };

  programs.firefox.enable = true;
  programs.firefox.package = pkgs.librewolf;

  dev.user = {
    name = "jaov";
    email = "9527341+joaov-007@users.noreply.github.com";
  };

  system.stateVersion = "25.11";
}

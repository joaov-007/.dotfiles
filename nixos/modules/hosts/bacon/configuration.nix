# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).
{
  pkgs,
  config,
  lib,
  ...
}:
{
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

  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  services.xserver.xkb.layout = "us";

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

  users.users.root.hashedPassword = "$y$j9T$6YV.M5P9XJvUfZiU2jhFm1$hg1a8nZbBqZ8i5Fr0O9Q.GeBWgoWWE2o5mhzPTAAo4B";

  users.users.jaov = {
    isNormalUser = true;
    extraGroups = ["wheel" "adm" "audio" "input" "video" "networkmanager"];
    hashedPassword = "$y$j9T$6YV.M5P9XJvUfZiU2jhFm1$hg1a8nZbBqZ8i5Fr0O9Q.GeBWgoWWE2o5mhzPTAAo4B";
  };

  programs.firefox.enable = true;
  programs.firefox.package = pkgs.librewolf;

  system.stateVersion = "25.11";
}

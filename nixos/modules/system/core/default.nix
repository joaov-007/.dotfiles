{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.core = {
    pkgs,
    lib,
    ...
  }: let
    modules = with self.nixosModules; [
      boot
      locale
      audio
      settings
      user
      nix-ld
      security
      fonts
      power
      ollama
    ];
  in {
    imports =
      [
      ]
      ++ modules;
    environment.systemPackages = with pkgs; [
      gzip
      util-linux
      unzip
      p7zip
      usbutils
      lsof
      gvfs
      libnotify
    ];
    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    services = {
      avahi.enable = true;
    };
    system.stateVersion = "26.05";
  };
}

{
  self,
  inputs,
  ...
}: {
  flake.modules.nixos.core = {
    pkgs,
    lib,
    ...
  }: let
    modules = with self.modules.nixos; [
      boot
      locale
      audio
      # settings
      user
      nix
      nix-ld
      security
      fonts
      power
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
      wl-clipboard
      xclip
    ];
    environment.variables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    system.stateVersion = "26.05";
  };
}

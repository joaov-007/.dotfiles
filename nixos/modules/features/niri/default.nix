{
  inputs,
  self,
  ...
}: {
  flake.modules.nixos.niri = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      inputs.noctalia.nixosModules.default
    ];

    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
    };

    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = true;
    };

    services.displayManager.ly.enable = true;
    services.displayManager.defaultSession = lib.mkForce "niri";
  };

  flake.modules.homeManager.niri = {pkgs, ...}: {
    programs.alacritty.enable = true;

    home.packages = [pkgs.nautilus];
  };
}

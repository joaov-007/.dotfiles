{
  self,
  inputs,
  ...
}: {
  flake.modules.nixos.flatpak = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    services.flatpak.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };
  };
}

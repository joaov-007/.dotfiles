{
  config,
  inputs,
  lib,
  ...
}: {
  imports = [
    ./configuration.nix
    ./hardware-configuration.nix
    ./networking.nix

    inputs.nixos-hardware.nixosModules.common-cpu-intel # Intel CPUs

    # enable tlp
    inputs.nixos-hardware.nixosModules.common-pc-laptop # Laptops

    inputs.nixos-hardware.nixosModules.common-pc-ssd # SSD storage
    inputs.nix-flatpak.nixosModules.nix-flatpak
    inputs.nix-index-database.nixosModules.default
  ];

  home-manager.users = lib.genAttrs (lib.attrNames config.dev.user.users) (user: {
    home.username = user;
    home.homeDirectory = "/home/${user}";
    imports = [
      ./home.nix
      ../../modules/home
    ];
  });
}

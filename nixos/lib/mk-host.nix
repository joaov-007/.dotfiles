{
  inputs,
  system,
}: {
  host,
  pkgs-stable,
}:
inputs.nixpkgs.lib.nixosSystem {
  inherit system;

  specialArgs = {
    inherit inputs pkgs-stable;
  };

  modules = [
    ../hosts/${host}
    ../modules/system
    inputs.impermanence.nixosModules.impermanence
    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops

    {
      home-manager = {
        useUserPackages = true;
        useGlobalPkgs = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {
          inherit inputs pkgs-stable;
        };
      };
    }
  ];
}

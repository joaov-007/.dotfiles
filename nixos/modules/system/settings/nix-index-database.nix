{inputs, ...}: {
  flake.nixosModules.nixIndexDatabase = {...}: {
    imports = [
      inputs.nix-index-database.nixosModules.default
    ];
    config = {
      programs.nix-index-database.comma.enable = true;
    };
  };
}

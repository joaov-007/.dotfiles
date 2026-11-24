{inputs, ...}: {
  flake.nixosModules.nixIndexDatabase = {config, ...}: {
    imports = [
      inputs.nix-index-database.nixosModules.default
    ];
    config = {
      assertions = [
        {
          assertion = config.programs.nix-index-database.comma.enable;
          message = "nix-index-database comma must be enabled";
        }
      ];

      programs.nix-index-database.comma.enable = true;
    };
  };
}

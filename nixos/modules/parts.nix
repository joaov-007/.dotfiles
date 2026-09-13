{inputs, ...}: {
  imports = [
    inputs.home-manager.flakeModules.home-manager
    inputs.agenix-rekey.flakeModule
  ];

  config = {
    systems = [
      "aarch64-linux"
      "x86_64-linux"
    ];

    perSystem = {pkgs, ...}: {
      formatter = pkgs.alejandra;
    };
  };
}

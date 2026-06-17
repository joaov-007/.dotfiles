{inputs, ...}: {
  imports = [
    inputs.home-manager.flakeModules.home-manager
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

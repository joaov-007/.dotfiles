{inputs, ...}: {
  imports = [
    inputs.home-manager.nixosModules.default
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.jaov = {
      imports = [
        ../../home/cli.nix
        ../../home/git.nix
        ../../home/shell.nix
      ];

      home.stateVersion = "25.11";
    };
  };
}

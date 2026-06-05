{
  inputs,
  config,
  pkgs,
  ...
}: {
  imports = [
    inputs.home-manager.nixosModules.default
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.jaov = {
      imports = let
        homeDir = ./../../home;
        inherit (builtins) filter baseNameOf;
        allFiles = pkgs.lib.filesystem.listFilesRecursive homeDir;
        moduleFiles =
          filter
          (f: pkgs.lib.hasSuffix ".nix" f && baseNameOf f != "default.nix")
          allFiles;
      in
        moduleFiles;

      dev.user = {
        name = config.dev.user.name;
        email = config.dev.user.email;
      };

      home.stateVersion = "25.11";
    };
  };
}

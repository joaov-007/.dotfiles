{inputs,  pkgs, ...}: {
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
          moduleFiles = filter
            (f: pkgs.lib.hasSuffix ".nix" f && baseNameOf f != "default.nix")
            allFiles;
        in moduleFiles;

        home.stateVersion = "25.11";
      };
    };
}

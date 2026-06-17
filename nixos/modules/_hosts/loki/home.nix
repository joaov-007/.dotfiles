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
    extraSpecialArgs = { inherit inputs; };

    users.jaov = {
      imports = let
        homeDir = ./../../_home;
        inherit (builtins) filter baseNameOf;
        allFiles = pkgs.lib.filesystem.listFilesRecursive homeDir;
        moduleFiles =
          filter
          (f: pkgs.lib.hasSuffix ".nix" f && baseNameOf f != "default.nix")
          allFiles;
      in
        moduleFiles ++ [
          inputs.nvim-config.homeManagerModules.default
          inputs.kitty-config.homeManagerModules.default
        ];

      dev.user = {
        name = config.dev.user.name;
        email = config.dev.user.email;
      };

      home.stateVersion = "25.11";
    };
  };
}

{
  description = "NixOS configuration";

  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    sops-nix.url = "github:Mic92/sops-nix";
    preservation.url = "github:nix-community/preservation";
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-config = {
      url = "git+ssh://git@codeberg.org/joaov-007/nvim.git?ref=develop";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        ({ lib, ... }: {
          imports = builtins.filter
            (f: !lib.hasInfix "/_" (toString f) && lib.hasSuffix ".nix" (toString f))
            (lib.filesystem.listFilesRecursive ./modules);
        })
        inputs.home-manager.flakeModules.default
      ];

      systems = [ "x86_64-linux" ];

      perSystem = { pkgs, system, ... }: {
        packages.nvim-config = inputs.nvim-config.packages.${system}.default;
      };
    };
}

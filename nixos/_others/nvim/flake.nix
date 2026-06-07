{
  description = "Neovim configuration (lazy.nvim)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs @ { flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      perSystem = { pkgs, self', ... }: {
        packages = rec {
          config = pkgs.stdenv.mkDerivation {
            name = "nvim-config";
            src = ./.;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              cp -r $src/* $out/
              rm -f $out/flake.nix $out/flake.lock
            '';
          };
          default = config;
        };

        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            neovim
            lua-language-server
            stylua
          ];
        };
      };

      flake = {
        nixosModules.default = { pkgs, ... }: {
          environment.systemPackages = with pkgs; [
            neovim
            python3Packages.pynvim
          ];
        };

        homeManagerModules.default = { pkgs, ... }: let
          configDir = pkgs.stdenv.mkDerivation {
            name = "nvim-config";
            src = ./.;
            dontBuild = true;
            installPhase = ''
              mkdir -p $out
              cp -r $src/* $out/
              rm -f $out/flake.nix $out/flake.lock
            '';
          };
        in {
          home.packages = with pkgs; [
            neovim
            python3Packages.pynvim
          ];

          home.file.".config/nvim" = {
            source = "${configDir}";
            recursive = true;
            force = true;
          };
        };
      };
    };
}

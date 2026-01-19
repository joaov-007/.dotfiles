{
  description = "Bacon Setup for personal use and fun";

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    sops-nix,
    ...
  }: let
    system = "x86_64-linux";

    mylib = import ./lib {
      inherit inputs system;
    };

    inherit (mylib) lib pkgs hosts mkHost;
  in {
    nixosConfigurations = lib.genAttrs hosts (
      host:
        mkHost {
          inherit host;
          pkgs-stable = pkgs.pkgs-stable;
        }
    );

    formatter.${system} = pkgs.pkgs.alejandra;
  };

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "nixpkgs/nixos-25.11";

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    impermanence.url = "github:nix-community/impermanence";
  };
}

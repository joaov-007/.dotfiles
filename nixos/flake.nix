{
  description = "Bacon Setup for personal use and fun";

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

  outputs = inputs @ {
    self,
    nixpkgs,
    nixpkgs-stable,
    home-manager,
    sops-nix,
    impermanence,
    ...
  }: let
    system = "x86_64-linux";

    lib = nixpkgs-stable.lib;

    hosts = lib.pipe ./hosts [
      lib.readDir
      (lib.filterAttrs (_: type: type == "directory"))
      lib.attrsets.attrNames
    ];

    overlays =
      builtins.attrValues (import ./overlays {inherit lib;});

    pkgs = import inputs.nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [(import ./overlays {inherit inputs system;})];
    };

    mkHost = host:
      nixpkgs.lib.nixosSystem {

        specialArgs = {
          inherit inputs;
          pkgs-stable = pkgs.stable;
        };

        modules = [
          ./hosts/${host}
          ./modules/system

          impermanence.nixosModules.impermanence
          home-manager.nixosModules.home-manager
          sops-nix.nixosModules.sops

          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              backupFileExtension = "bk";

              extraSpecialArgs = {
                inherit inputs;
                pkgs-stable = pkgs.stable;
              };
            };
          }
        ];
      };
  in {
    nixosConfigurations =
      lib.genAttrs hosts mkHost;

    formatter.${system} = pkgs.alejandra;
  };
}

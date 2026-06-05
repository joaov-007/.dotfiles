{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    preservation.url = "github:nix-community/preservation";
    sops-nix.url = "github:Mic92/sops-nix";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
  in {
    formatter.${system} = pkgs.alejandra;

    nixosConfigurations.bacon = nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit self inputs;};
      modules = [
        ./modules/hosts/bacon
      ];
    };
  };
}

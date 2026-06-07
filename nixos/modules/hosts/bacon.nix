{ inputs, self, ... }: {
  flake.nixosConfigurations.bacon = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = { inherit inputs self; };
    modules = [
      ./../_hosts/bacon/default.nix
    ];
  };
}

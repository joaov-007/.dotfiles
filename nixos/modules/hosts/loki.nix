{ inputs, self, ... }: {
  flake.nixosConfigurations.loki = inputs.nixpkgs.lib.nixosSystem {
    system = "aarch64-linux";
    specialArgs = { inherit inputs; };
    modules = [
      ./../_hosts/loki/default.nix
    ];
  };
}

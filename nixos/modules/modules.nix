{inputs, ...}: {
  flake.nixosModules.extraModules = {
    imports = [
      inputs.chaotic.nixosModules.default
    ];
    nixpkgs.overlays = [
      inputs.nur.overlays.default
      inputs.chaotic.overlays.default
    ];
  };
}

{
  inputs,
  system,
}: let
  lib = inputs.nixpkgs.lib;

  nixpkgsConfig = {
    allowUnfree = true;
    allowUnfreePredicate = _: true;
  };

  overlays =
    builtins.attrValues (import ../overlays {inherit lib;});

  mkPkgs = src:
    import src {
      inherit system overlays;
      config = nixpkgsConfig;
    };

  pkgs-patched = (mkPkgs inputs.nixpkgs).applyPatches {
    name = "nixpkgs-patched";
    src = inputs.nixpkgs;
    patches = [];
  };
in {
  pkgs = mkPkgs pkgs-patched;
  pkgs-stable = mkPkgs inputs.nixpkgs-stable;
}

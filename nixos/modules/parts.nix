{
  inputs,
  lib,
  ...
}: let
  allowedUnfreePackages = ["openbot"];
in {
  options.flake = {
    niriSettings = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      default = _: {};
      description = "Factory for shared settings for the wrapped Niri package.";
    };
  };

  imports = [
    inputs.flake-parts.flakeModules.modules
  ];

  config = {
    systems = [
      "x86_64-linux"
      "x86_64-darwin"
      "aarch64-linux"
      "aarch64-darwin"
    ];

    perSystem = {
      pkgs,
      system,
      ...
    }: {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config.allowUnfreePredicate = pkg:
          builtins.elem (lib.getName pkg) allowedUnfreePackages;
      };

      formatter = pkgs.alejandra;
    };
  };
}

{
  inputs,
  lib,
  ...
}: let
  allowedUnfreePackages = ["openbot"];
in {
  options.flake = {
    desktopPalette = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Shared Base16 color overrides for Stylix and Niri.";
    };

    noctaliaSettings = lib.mkOption {
      type = lib.types.attrs;
      default = {};
      description = "Shared settings for the wrapped and Home Manager Noctalia configurations.";
    };

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

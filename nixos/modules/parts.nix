{
  inputs,
  lib,
  ...
}: {
  options.flake.yaziSettings = lib.mkOption {
    type = lib.types.attrs;
    default = {};
    description = "Shared settings for the wrapped Yazi package.";
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

    perSystem = {pkgs, ...}: {
      formatter = pkgs.alejandra;
    };
  };
}

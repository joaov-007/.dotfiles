{
  lib,
  config,
  pkgs,
  inputs,
  ...
}: let
  cfg = config.dev.system.updates;
in {
  options = {
    dev.system.updates.enable = lib.mkEnableOption "Enable system auto update";
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      flake = inputs.self.outPath;
      flags = [
        "-L" # print build logs
      ];
    };
  };
}

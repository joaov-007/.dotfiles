{
  lib,
  config,
  pkgs,
  ...
}: let
  cfg = config.dev.boot.systemd-boot;
in {
  options = {
    dev.boot.systemd-boot.enable = lib.mkEnableOption "Enable systemd-boot";
  };

  config = lib.mkIf cfg.enable {
    boot.loader.systemd-boot.enable = true;
    boot.loader.efi.canTouchEfiVariables = true;
    boot.loader.systemd-boot.configurationLimit = 12;
    boot.initrd.systemd.enable = true;
  };
}

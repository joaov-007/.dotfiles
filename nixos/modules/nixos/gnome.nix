{
  config,
  lib,
  ...
}: let
  cfg = config.dev.desktop.gnome;
in {
  options.dev.desktop.gnome = {
    enable = lib.mkEnableOption "GNOME desktop environment" // {default = true;};
  };

  config = lib.mkIf cfg.enable {
    services.xserver.enable = true;
    services.displayManager.gdm.enable = true;
    services.desktopManager.gnome.enable = true;
  };
}

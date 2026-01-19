{
  config,
  lib,
  ...
}: let
  cfg = config.dev.boot.plymouth;
in {
  options = {
    dev.boot.plymouth = {
      enable = lib.mkEnableOption "Toggle plymouth settings";
    };
  };

  config = lib.mkIf cfg.enable {
    boot = {
      loader.timeout = 3;

      plymouth = {
        enable = true;
        theme = "bgrt";
        #  themePackages = with pkgs; [
        #    # By default we would install all themes
        #    (adi1090x-plymouth-themes.override {
        #      selected_themes = [ "" ];
        #    })
        #  ];
      };

      # Enable "Silent boot"
      consoleLogLevel = 3;

      initrd.verbose = false;

      kernelParams = [
        "quiet"
        "splash"
        "boot.shell_on_fail"
        "udev.log_priority=3"
        "rd.systemd.show_status=auto"
      ];
    };
  };
}

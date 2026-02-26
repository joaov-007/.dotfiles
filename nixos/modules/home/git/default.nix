{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dev.home.git;
in {
  options.dev.home.git = {
    enable = lib.mkEnableOption "Toggle git config";
    userName = lib.mkOption {
      type = lib.types.str;
    };
    userEmail = lib.mkOption {
      type = lib.types.str;
    };
  };
  config = lib.mkIf cfg.enable {
    programs.git = {
      enable = true;

      userName = cfg.userName;
      userEmail = cfg.userEmail;

      lfs.enable = true;

      extraConfig = {
      };
    };
    home.packages = with pkgs; [
      btop
      git-lfs
    ];
  };
}

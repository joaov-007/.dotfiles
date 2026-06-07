{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.dev.zellij;
in {
  options.dev.zellij = {
    enable = mkEnableOption "zellij terminal multiplexer" // {default = true;};
  };

  config = mkIf cfg.enable {
    home.packages = [pkgs.zellij];
    # TODO: create a vim keybinds like
  };
}

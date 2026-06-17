{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.dev.git;
in {
  options.dev.git = {
    enable = mkEnableOption "Git configuration for user" // {default = true;};
  };

  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user = {
          name = config.dev.user.name;
          email = config.dev.user.email;
        };
        push.autoSetupRemote = true;
        pull.rebase = true;
        diff.submodule = "log";
        alias = {
          st = "status";
          ci = "commit";
          br = "branch";
          co = "checkout";
          df = "diff";
        };
      };
    };
  };

  #  assertions = mkIf cfg.enable [
  #    {
  #      assertion = config.programs.git.settings.user.name != "";
  #      message = "Git user.name must be set when dev.git is enabled";
  #    }
  #    {
  #      assertion = config.programs.git.settings.user.email != "";
  #      message = "Git user.email must be set when dev.git is enabled";
  #    }
  #  ];
}

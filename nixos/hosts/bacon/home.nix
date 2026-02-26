{
  config,
  pkgs,
  lib,
  ...
}: {
  # Set environment variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    SHELL = pkgs.zsh;
  };

  programs.git = {
      enable = true;
      lfs.enable = true;
      userName = "joaov-007";
      userEmail = "9527341+joaov-007@users.noreply.github.com";
      settings = {
        branch.autosetuprebase = "always";
        color.ui = true;
        core.preloadindex = true;
        fetch.prune = true;
        gc.auto = 10000;
        gc.autoPackLimit = 50;
        pull.rebase = true;
        pull.default = "current";
	      push.autoSetupRemote = true;
	      push.default = "current";
	      rebase.autoSquash = true;
	      rebase.autoStash = true;
	      rebase.stat = true;
      };
  };


  home.packages = with pkgs; [
    btop
    git-lfs
  ];

  services.ssh-agent = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh.enable = true;
  programs.zsh.dotDir = "${config.xdg.configHome}/zsh";

  services.syncthing.enable = true;

  xdg.enable = true;
  xdg.userDirs.createDirectories = true;

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    enableBashIntegration = true;
  };

  programs.obsidian.enable = true;
  programs.home-manager.enable = true;
  home.stateVersion = "25.11";
}

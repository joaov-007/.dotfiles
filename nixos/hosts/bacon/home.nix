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

  # User packages
  home.packages = with pkgs; [
    btop
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

  programs.home-manager.enable = true;
  home.stateVersion = "25.11";
}

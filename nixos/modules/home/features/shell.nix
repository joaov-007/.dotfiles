{...}: {
  flake.homeModules.shell = {pkgs, ...}: {
    home.packages = [pkgs.yt-dlp];
    programs.btop.enable = true;
    programs.zoxide.enable = true;
    programs.starship.enable = true;
    programs.bash.enable = true;
    services.ssh-agent.enable = true;
    programs.lazygit = {
      enable = true;
      enableBashIntegration = true;
      settings.gui.nerdFontsVersion = "3";
    };
    programs.devenv = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.herdr.enable = true;
    programs.atuin = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}

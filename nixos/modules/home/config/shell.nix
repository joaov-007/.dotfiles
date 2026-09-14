{...}: {
  flake.homeModules.shell = {pkgs, ...}: {
    home.packages = with pkgs; [
      yt-dlp
      blesh
      # Rust CLI replacements
      eza
      bat
      ripgrep
      fd
      dust
      delta
      sd
      jq
      gnumake
      just
      yazi
      ouch
    ];
    programs.bat = {
      enable = true;
      config.theme = "base16-stylix";
    };
    home.sessionPath = ["$HOME/.local/bin"];
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
    programs.btop.enable = true;
    programs.zoxide.enable = true;
    programs.starship.enable = true;
    programs.bash = {
      enable = true;
      initExtra = "source ${pkgs.blesh}/share/blesh/ble.sh";
    };
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

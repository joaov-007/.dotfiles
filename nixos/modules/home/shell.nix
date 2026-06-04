{pkgs, ...}: {
  programs.bash = {
    enable = true;
    shellAliases = {
      ll = "ls -l";
      la = "ls -a";
      l = "ls -F";
      gs = "git status";
      gp = "git push";
      gl = "git log --oneline --graph";
      v = "nvim";
    };
    initExtra = ''
      source ${pkgs.blesh}/share/blesh/ble.sh
    '';
  };

  home.packages = with pkgs; [
    blesh
  ];

  xdg.configFile."blesh/init.sh".text = ''
    bleopt complete_auto_delay=100
    bleopt complete_auto_history=1
    bleopt complete_menu_style=align-nowrap
    bleopt complete_menu_maxlines=15
    ble-face auto_complete='fg=240,underline,italic'
  '';

  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.starship = {
    enable = true;
    enableBashIntegration = true;
  };

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };

  programs.zoxide = {
    enable = true;
   enableBashIntegration = true;
  };

  programs.atuin = {
    enable = true;
    enableBashIntegration = true;
    settings = {
      # auto_sync = false;
      # sync_frequency = "5m";
    };
  };
}

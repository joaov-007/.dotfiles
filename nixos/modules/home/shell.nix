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
      cat = "bat";
      catn = "bat -n";
      h = "history";
      q = "exit";
      du = "du -h";
      df = "df -h";
      tree = "tree -C";
    };
    initExtra = ''
        source ${pkgs.blesh}/share/blesh/ble.sh
        mkcd() {
       (( $# == 1 )) || {
           printf 'Usage: mkcd DIR\n' >&2
           return 1
       }

       mkdir -p -- "$1" &&
           cd -- "$1"
      }

             cpmk() {
              (( $# == 2 )) || {
                  printf 'Usage: cpmk SRC DEST\n' >&2
                  return 1
              }

              mkdir -p -- "$(dirname -- "$2")" &&
                  install -D -- "$1" "$2"
             }

             ..() { local n; n=$1; [ -z "$n" ] && n=1; cd "$(printf '%0.s../' $(seq 1 $n))"; }
             myip() { curl -s ifconfig.me; echo; }
             ports() { ss -tlnp; }
             killport() { kill -9 $(lsof -ti:"$1"); }
             bak() { cp -r "$1" "$1.bak"; }
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

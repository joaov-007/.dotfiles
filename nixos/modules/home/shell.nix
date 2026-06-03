{...}: {
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
      # set up fzf key bindings and fuzzy completion
      eval "$(fzf --bash)" 2>/dev/null
    '';
  };

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
}

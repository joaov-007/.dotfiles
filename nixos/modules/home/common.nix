{...}: {
  flake.homeModules.common = {
    home.stateVersion = "26.05";
    programs.home-manager.enable = true;
    programs.opencode.enable = true;
    programs.mise.enable = true;
    home.file.".config/nixpkgs/config.nix".text = ''
      {
        allowUnfreePredicate = pkg: (pkg.pname or pkg.name) == "ventoy";
        permittedInsecurePackages = [ "ventoy-1.1.12" ];
      }
    '';
    home.sessionPath = ["$HOME/.local/bin"];
    home.sessionVariables = {
      EDITOR = "nvim";
      VISUAL = "nvim";
    };
  };
}

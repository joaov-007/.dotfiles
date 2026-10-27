{pkgs, ...}: {
  flake.homeModules.git = {config, ...}: {
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user.name = "joaov";
        user.email = "9527341+joaov-007@users.noreply.github.com";
        safe.directory = "/home/joaov/.dotfiles";
        merge.conflictstyle = "diff3";
        diff.colorMoved = "default";
      };
    };
    programs.delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        navigate = true;
        line-numbers = true;
        syntax-theme = "base16-stylix";
      };
    };
    programs.gh = {
      enable = true;
      gitCredentialHelper.enable = true;
      settings.git_protocol = "ssh";
    };
    programs.gh-dash.enable = true;
  };
}

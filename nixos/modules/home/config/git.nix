{pkgs, ...}: {
  flake.homeModules.git = {
    programs.git = {
      enable = true;
      lfs.enable = true;
      settings = {
        user.name = "joaov";
        user.email = "9527341+joaov-007@users.noreply.github.com";
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

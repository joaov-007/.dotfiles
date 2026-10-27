{self, ...}: {
  flake.homeModules.yazi = {pkgs, ...}: {
    programs.yazi = {
      enable = true;
      enableBashIntegration = true;
    };
  };
}

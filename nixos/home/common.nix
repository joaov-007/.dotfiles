{inputs, ...}: {
  flake.homeModules.common = {
    programs.mise.enable = true;
    programs.home-manager.enable = true;
    home.stateVersion = "26.05";
  };
}

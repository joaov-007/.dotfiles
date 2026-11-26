{inputs, ...}: {
  flake.modules.homeManager.common = {
    programs.mise.enable = true;
    programs.home-manager.enable = true;
    home.stateVersion = "26.05";
  };
}

{...}: {
  flake.homeModules.xdg = {
    xdg = {
      enable = true;
      cacheHome = "$HOME/.cache";
      configHome = "$HOME/.config";
      dataHome = "$HOME/.local/share";
      stateHome = "$HOME/.local/state";
    };
  };
}

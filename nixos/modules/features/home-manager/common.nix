{inputs, ...}: {
  flake.modules.homeManager.common = {config, ...}: {
    _module.args.symlinkRoot = "${config.home.homeDirectory}/.dotfiles";

    programs.mise.enable = true;
    programs.home-manager.enable = true;
    home.stateVersion = "26.05";
  };
}

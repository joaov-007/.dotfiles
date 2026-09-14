{...}: {
  flake.homeModules.nvim = {config, ...}: {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      viAlias = true;
      vimAlias = true;
    };
  };
}

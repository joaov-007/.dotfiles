{...}: {
  flake.modules.homeManager.nvim = {
    config,
    symlinkRoot,
    ...
  }: {
    # Keep Neovim configuration editable in the dotfiles checkout.
    stylix.targets.neovim.enable = false;

    home.file.".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${symlinkRoot}/config/shared/.config/nvim";
      recursive = false;
    };
  };
}

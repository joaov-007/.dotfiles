{...}: {
  flake.modules.homeManager.nvim = {
    pkgs,
    config,
    symlinkRoot,
    ...
  }: {
    # Keep language servers and formatters reproducible, with their NixOS
    # runtime dependencies supplied by Nix rather than downloaded binaries.
    home.packages = with pkgs; [
      neovim
      nixd
      alejandra
      lua-language-server
      marksman
    ];

    # Keep Neovim configuration editable in the dotfiles checkout.
    stylix.targets.neovim.enable = false;

    home.file.".config/nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${symlinkRoot}/config/shared/.config/nvim";
      recursive = false;
    };
  };
}

{
  pkgs,
  config,
  ...
}: {
  home.packages = with pkgs; [
    neovim
    python3Packages.pynvim
  ];

  home.file.".config/nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/modules/others/nvim";
    recursive = true;
    force = true;
  };
}

{pkgs, config, ...}: {
  home.packages = with pkgs; [
    # system monitoring
    btop

    # file management
    tree
    yazi
    ripgrep
    fd
    jq
    yq

    # archives
    unzip
    zip
    xz

    # misc
    wget
    curl
    hledger
    opencode
    obsidian
    calibre
    alejandra

    # LSP servers
    pyright
    nixd
    lua-language-server
    marksman

    # Formaters
    shfmt

    # Python provider for Neovim
    python3Packages.pynvim

    # Neovim (nightly from overlay)
    neovim
  ];

  home.file.".config/nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink (
      "${config.home.homeDirectory}/.dotfiles/modules/others/nvim"
    );
    recursive = true;
    force = true;
  };
}

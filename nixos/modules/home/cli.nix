{pkgs, ...}: {
  home.packages = with pkgs; [
    # system monitoring
    btop

    # file management
    tree
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
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    withPython3 = true;
  };

  xdg.configFile."nvim" = {
    source = ../others/nvim;
    recursive = true;
  };
}

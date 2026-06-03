{pkgs, ...}: {
  home.packages = with pkgs; [
    # system monitoring
    btop
    htop

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
  ];

  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };
}

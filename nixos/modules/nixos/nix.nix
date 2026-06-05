{
  config,
  pkgs,
  ...
}: {
  nix = {
    package = pkgs.lix;
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
    settings = {
      substituters = [
        "https://cache.nixos.org"
        "https://hyprland.cachix.org"
        "https://nix-community.cachix.org"
        "https://chaotic-nyx.cachix.org"
        "https://neovim.cachix.org"
        "https://devenv.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
        "neovim.cachix.org-1:4okzfZQ2FD3UlcYPzDQ444C6XDJjbmtR8PhOLVqHi9E="
        "devenv.cachix.org-1:w1cLUi8dv3hnoSPGAuibQv+f9TZLr6cv/Hm9XgU50cw="
      ];
      trusted-users = ["@wheel"];
      auto-optimise-store = true;
    };
    extraOptions = ''
      experimental-features = nix-command flakes
    '';
  };

  programs.nix-ld = {
    enable = true;
    libraries = [
      pkgs.stdenv.cc.cc
      pkgs.zlib
      pkgs.fuse3
      pkgs.icu
      pkgs.nss
      pkgs.openssl
      pkgs.curl
      pkgs.expat
      pkgs.libx11
      pkgs.vulkan-headers
      pkgs.vulkan-loader
      pkgs.vulkan-tools
    ];
  };
}

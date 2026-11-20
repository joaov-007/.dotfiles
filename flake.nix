{
  description = "Bacon Nixos Configs for personal prefs for a dev";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";

    preservation.url = "github:nix-community/preservation";

    flake-parts.url = "github:hercules-ci/flake-parts";

    import-tree.url = "github:denful/import-tree";

    wrappers.url = "github:Lassulus/wrappers";
    wrappers-modules.url = "github:BirdeeHub/nix-wrapper-modules";

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    nix-flatpak.url = "github:gmodena/nix-flatpak";

    neovim-nightly.url = "github:nix-community/neovim-nightly-overlay";

    nixos-anywhere.url = "github:nix-community/nixos-anywhere";

    noctalia = {
      url = "github:noctalia-dev/noctalia/cachix";
    };

    stylix = {
      url = "github:nix-community/stylix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur = {
      url = "github:nix-community/NUR";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pure-bash = {
      url = "github:krashikiworks/pure-prompt-bash";
      flake = false;
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake {inherit inputs;}
    (inputs.import-tree ./nixos);
}

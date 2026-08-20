{inputs, ...}: {
  flake.nixosModules.settings = {config, ...}: {
    config = {
      nix = {
        gc = {
          automatic = true;
          dates = "daily";
          options = "--delete-older-than 8d";
        };
        optimise.automatic = true;
        settings = {
          # only users in the `users` group may use the daemon
          allowed-users = ["@users"];
          cores = 2;
          experimental-features = ["nix-command" "flakes"];
          extra-substituters = [
            "https://cache.nixos.org"
            "https://nix-community.cachix.org"
            "https://noctalia.cachix.org"
            "https://nixpkgs-wayland.cachix.org"
            "https://nix-gaming.cachix.org"
            "https://nyx-cache.chaotic.cx"
          ];
          extra-trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
            "nixpkgs-wayland.cachix.org-1:3lwxaILxMRkVhehr5StQprHdEo4IrE8sRho9R9HOLYA="
            "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
            "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
          ];
        };
      };
    };
  };
}

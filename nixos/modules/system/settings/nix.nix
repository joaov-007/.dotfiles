{inputs, ...}: {
  flake.nixosModules.settings = {
    config,
    lib,
    pkgs,
    ...
  }: {
    config = {
      # QEMU binfmt for cross-compilation (aarch64 ↔ x86_64)
      # boot.binfmt.emulatedSystems = ["aarch64-linux"];

      nix = {
        gc = {
          automatic = true;
          dates = "daily";
          options = "--delete-older-than 10d";
        };
        optimise.automatic = true;
        settings = {
          # only users in the `users` group may use the daemon
          allowed-users = ["@users"];
          cores = 2;
          experimental-features = ["nix-command" "flakes"];
          # Cross-compilation support (aarch64 for Raspberry Pi)
          extra-platforms = "aarch64-linux x86_64-linux";
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

      # Optional: Use Raspberry Pi as remote builder
      # Add to nix block above, replace <pi-ip> with your Pi's IP:
      #   buildMachines = [{
      #     hostName = "<pi-ip>";
      #     system = "aarch64-linux";
      #     maxJobs = 4;
      #     speedFactor = 2;
      #     supportedFeatures = [ "kvm" "big-parallel" ];
      #   }];
      #   distributedBuilds = true;
    };
  };
}

{inputs, ...}: {
  flake.nixosModules.agenix = {
    config,
    pkgs,
    lib,
    ...
  }: {
    imports = [
      inputs.agenix.nixosModules.default
      inputs.agenix-rekey.nixosModules.default
    ];

    environment.systemPackages = with pkgs; [
      agenix
      rage
    ];

    # ponytail: hostPubkey is per-host — set in the host's configuration.nix
    # age.rekey.hostPubkey = "ssh-ed25519 AAAA...";
  };
}

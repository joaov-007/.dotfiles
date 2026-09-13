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

    environment.systemPackages = [
      inputs.agenix.packages.${pkgs.system}.agenix
      pkgs.rage
    ];

    # ponytail: openssh disabled, no host keys. Use user SSH key for decryption.
    age.identityPaths = ["/home/joaov/.ssh/github"];

    # ponytail: masterIdentities for rekeying — the key that encrypts secrets
    # at rest. Rekeyed per-host on activation.
    age.rekey.masterIdentities = ["/home/joaov/.ssh/github"];
  };
}

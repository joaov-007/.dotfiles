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

    # ponytail: openssh is disabled, so agenix can't auto-detect identity paths.
    # point to the host key directly — needed for decryption.
    age.identityPaths = ["/etc/ssh/ssh_host_ed25519_key"];

    # ponytail: masterIdentities for rekeying — the key that encrypts secrets
    # at rest. The host key re-encrypts per-host on activation.
    rekey.masterIdentities = ["/etc/ssh/ssh_host_ed25519_key"];
  };
}

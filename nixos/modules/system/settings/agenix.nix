{self, inputs, ...}: {
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
      inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.agenix
      pkgs.rage
    ];

    # ponytail: dedicated age key — no passphrase, used for decryption.
    age.identityPaths = ["/home/joaov/.config/age/agenix-rekey.txt"];

    age.rekey = {
      # Master identity — encrypts secrets at rest in the repo.
      masterIdentities = ["/home/joaov/.config/age/agenix-rekey.txt"];
      storageMode = "local";
      # self resolves to the flake root, not relative to this file.
      localStorageDir = self + "/secrets/rekeyed/${config.networking.hostName}";
    };
  };
}

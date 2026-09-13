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
      inputs.agenix.packages.${pkgs.system}.agenix
      pkgs.rage
    ];

    # ponytail: openssh disabled, no host keys. Use user SSH key for decryption.
    age.identityPaths = ["/home/joaov/.ssh/github"];

    age.rekey = {
      # Master identity — encrypts secrets at rest in the repo.
      masterIdentities = ["/home/joaov/.ssh/github"];
      storageMode = "local";
      # self resolves to the flake root, not relative to this file.
      localStorageDir = self + "/secrets/rekeyed/${config.networking.hostName}";
    };
  };
}

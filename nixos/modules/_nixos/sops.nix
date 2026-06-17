{
  inputs,
  config,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = "${inputs.self.outPath}/secrets/secrets.yaml";
  sops.age.keyFile = "/home/jaov/.config/sops/age/keys.txt";

  sops.secrets."jaov-password" = {
    neededForUsers = true;
  };
  sops.secrets."root-password" = {
    neededForUsers = true;
  };

  assertions = [
    {
      assertion = config.users.users ? jaov;
      message = "modules/nixos/sops.nix requires a `jaov` user to be defined.";
    }
  ];
}

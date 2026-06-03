{
  inputs,
  self,
  config,
  ...
}: {
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops.defaultSopsFile = self + "/secrets/secrets.yaml";
  sops.age.keyFile = "/home/jaov/.config/sops/age/keys.txt";

  assertions = [
    {
      assertion = config.users.users ? jaov;
      message = "modules/nixos/sops.nix requires a `jaov` user to be defined.";
    }
  ];
}

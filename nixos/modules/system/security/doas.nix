{
  self,
  inputs,
  ...
}: {
  flake.modules.nixos.doas = {
    pkgs,
    lib,
    config,
    ...
  }: {
    security.doas.enable = true;

    # Passwordless doas for joaov (requested 2026-11-27).
    security.doas.extraRules = [
      {
        users = ["joaov"];
        noPass = true;
        keepEnv = true;
      }
    ];

    security.sudo.enable = false;

    systemd.tmpfiles.rules = [
      "d /usr/local/bin 0755 root root -"
      "L+ /usr/local/bin/sudo - - - - /run/wrappers/bin/doas"
    ];

    environment = {
      systemPackages = [pkgs.doas];
      localBinInPath = true;
    };
  };
}

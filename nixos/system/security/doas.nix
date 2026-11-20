{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.doas = {
    pkgs,
    lib,
    config,
    ...
  }: {
    security.doas.enable = true;

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

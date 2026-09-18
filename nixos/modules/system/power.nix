{self, ...}: {
  flake.nixosModules.power = {lib, ...}: {
    powerManagement = {
      enable = true;
      powertop.enable = true;
    };
    services.thermald.enable = true;
  };
}

{self, ...}: {
<<<<<<< Updated upstream
  flake.nixosModules.power = {lib, ...}: {
||||||| Stash base
  flake.nixosModules.power = {
    lib,
    ...
  }: {
=======
  flake.nixosModules.power = {
    lib,
    config,
    ...
  }: {
>>>>>>> Stashed changes
    powerManagement = {
      enable = true;
      powertop.enable = true;
    };
    services.thermald.enable = true;

    assertions = [
      {
        assertion = config.powerManagement.enable;
        message = "power management must be enabled";
      }
      {
        assertion = config.powerManagement.powertop.enable;
        message = "powertop must be enabled for power profiling";
      }
    ];
  };
}

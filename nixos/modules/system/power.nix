{self, ...}: {
  flake.nixosModules.power = {
    lib,
    # Power management configuration for laptop energy efficiency
    config,
    ...
  }: {
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

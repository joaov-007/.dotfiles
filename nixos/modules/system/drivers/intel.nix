{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.intelDrivers = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-gpu-intel
    ];
    environment.systemPackages = with pkgs; [
      mesa
      vulkan-tools
    ];
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-vaapi-driver
        libva-vdpau-driver
      ];
    };

    assertions = [
      {
        assertion = config.hardware.graphics.enable;
        message = "graphics must be enabled for Intel GPU";
      }
      {
        assertion = config.hardware.graphics.enable32Bit;
        message = "32-bit graphics must be enabled for game compatibility";
      }
      {
        assertion = builtins.length config.hardware.graphics.extraPackages > 0;
        message = "Intel vaapi drivers must be in extraPackages";
      }
    ];
  };
}

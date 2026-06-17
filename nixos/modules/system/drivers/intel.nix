{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.intelDrivers = {
    pkgs,
    lib,
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
  };
}

{inputs, ...}: {
  flake.modules.nixos.intelDrivers = {pkgs, ...}: {
    imports = [
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      inputs.nixos-hardware.nixosModules.common-gpu-intel
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

{inputs, ...}: {
  flake.nixosModules.baconHardware = {
    config,
    lib,
    pkgs,
    modulesPath,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = ["vmd" "xhci_pci" "ahci" "nvme" "usb_storage" "usbhid" "sd_mod" "btrfs" "dm_crypt"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"];
    boot.extraModulePackages = [];

    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["mode=755" "size=4G"];
    };

    fileSystems."/.persistent" = {
      device = "/dev/mapper/crypt";
      fsType = "btrfs";
      options = ["subvol=@persistent" "compress=zstd:3" "defaults"];
    };

    boot.initrd.luks.devices."crypt".device = "/dev/disk/by-uuid/137d6cda-c074-4d74-80f4-47bc0d3b150e";

    fileSystems."/nix" = {
      device = "/dev/mapper/crypt";
      fsType = "btrfs";
      options = ["subvol=@nix" "compress=zstd:3" "defaults"];
    };

    fileSystems."/home" = {
      device = "/dev/mapper/crypt";
      fsType = "btrfs";
      options = ["subvol=@home" "compress=zstd:3" "defaults"];
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/C62D-32A5";
      fsType = "vfat";
      options = ["fmask=0022" "dmask=0022"];
    };

    swapDevices = [
      {device = "/dev/disk/by-uuid/147616fb-2b4c-4a1e-81d7-877ef4a252ac";}
    ];

    boot.resumeDevice = "/dev/disk/by-uuid/147616fb-2b4c-4a1e-81d7-877ef4a252ac";

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}

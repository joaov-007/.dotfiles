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
      options = ["subvol=@nix" "defaults"];
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
    hardware.enableAllFirmware = true;
    hardware.cpu.intel.updateMicrocode = lib.mkDefault true;

    assertions = [
      {
        assertion = builtins.elem "btrfs" config.boot.initrd.availableKernelModules;
        message = "btrfs must be in initrd availableKernelModules";
      }
      {
        assertion = builtins.elem "dm_crypt" config.boot.initrd.availableKernelModules;
        message = "dm_crypt must be in initrd availableKernelModules for LUKS";
      }
      {
        assertion = config.hardware.cpu.intel.updateMicrocode == true;
        message = "Intel microcode updates must be enabled";
      }
      {
        assertion = config.hardware.enableAllFirmware;
        message = "all firmware must be enabled";
      }
      {
        assertion = config.fileSystems."/".fsType == "tmpfs";
        message = "root filesystem must be tmpfs";
      }
      {
        assertion = config.fileSystems."/nix".fsType == "btrfs";
        message = "/nix must be btrfs";
      }
      {
        assertion = config.fileSystems."/home".fsType == "btrfs";
        message = "/home must be btrfs";
      }
      {
        assertion = config.fileSystems."/.persistent".fsType == "btrfs";
        message = "/.persistent must be btrfs for persistence";
      }
      {
        assertion = config.fileSystems."/boot".fsType == "vfat";
        message = "/boot must be vfat";
      }
    ];
  };
}

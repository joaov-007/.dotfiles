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

    boot.initrd.availableKernelModules = [
      "vmd"
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "btrfs"
      "dm_crypt"
    ];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"];
    boot.extraModulePackages = [];

    # Make btrfs-progs available to the NixOS swapfile service: on Btrfs it
    # uses `btrfs filesystem mkswapfile` (NOCOW + preallocated) automatically.
    boot.supportedFilesystems = ["btrfs"];

    boot.initrd.luks.devices."crypt0".device = "/dev/disk/by-uuid/8f6664cd-20ec-4575-b8eb-c12c81f242b5";

    fileSystems."/" = {
      device = "tmpfs";
      fsType = "tmpfs";
      options = ["mode=755" "size=4G"];
    };

    fileSystems."/nix" = {
      device = "/dev/mapper/crypt0";
      fsType = "btrfs";
      options = ["subvol=nix" "defaults"];
    };

    fileSystems."/home" = {
      device = "/dev/mapper/crypt0";
      fsType = "btrfs";
      options = ["subvol=home" "compress=zstd:3" "defaults"];
    };

    fileSystems."/var/log" = {
      device = "/dev/mapper/crypt0";
      fsType = "btrfs";
      options = ["subvol=log" "compress=zstd:3" "defaults"];
    };

    fileSystems."/swap" = {
      device = "/dev/mapper/crypt0";
      fsType = "btrfs";
      options = ["subvol=swap" "compress=none" "defaults"];
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/12CE-A600";
      fsType = "vfat";
      options = ["fmask=0022" "dmask=0022"];
    };

    swapDevices = [
      {
        device = "/swap/swapfile";
        size = 12 * 1024; # MiB; NixOS creates it with btrfs mkswapfile
      }
    ];

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
        assertion = config.boot.supportedFilesystems.btrfs or false;
        message = "btrfs must be in boot.supportedFilesystems for the swapfile service";
      }
      {
        assertion =
          config.boot.initrd.luks.devices."crypt0".device
          == "/dev/disk/by-uuid/8f6664cd-20ec-4575-b8eb-c12c81f242b5";
        message = "LUKS device crypt0 must point at the new encrypted Btrfs disk";
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
        assertion = config.fileSystems."/var/log".fsType == "btrfs";
        message = "/var/log must be btrfs";
      }
      {
        assertion =
          config.fileSystems."/swap".fsType
          == "btrfs"
          && builtins.elem "compress=none" config.fileSystems."/swap".options;
        message = "/swap must be btrfs with compress=none for the swapfile";
      }
      {
        assertion = config.fileSystems."/boot".fsType == "vfat";
        message = "/boot must be vfat";
      }
      {
        assertion =
          lib.length config.swapDevices
          == 1
          && (lib.head config.swapDevices).device == "/swap/swapfile"
          && (lib.head config.swapDevices).size == 12 * 1024;
        message = "swap must be the 12 GiB Btrfs swapfile at /swap/swapfile";
      }
      {
        assertion = config.boot.resumeDevice == null || config.boot.resumeDevice == "";
        message = "resume must be disabled: root is tmpfs and swap is a Btrfs swapfile";
      }
    ];
  };
}

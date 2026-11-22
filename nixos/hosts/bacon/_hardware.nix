{
  inputs,
  pkgs,
  lib,
  config,
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
    device = "/dev/mapper/crypt0";
    fsType = "btrfs";
    options = ["subvol=root" "compress=zstd:3" "defaults"];
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
}

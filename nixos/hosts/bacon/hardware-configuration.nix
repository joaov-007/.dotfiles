{
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [ "vmd" "xhci_pci" "ahci" "nvme" "usb_storage" "sd_mod" "dm-crypt" "aesni_intel" ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = ["kvm-intel"];
  boot.extraModulePackages = [];

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["subvol=/root" "noatime" "compress=zstd" "defaults"];
  };

  boot.initrd.luks.devices."cryptroot".device = "/dev/disk/by-label/NIXLUKS";

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/12CE-A600";
      fsType = "vfat";
      options = [ "defaults" ];
    };

  fileSystems."/home" =
    { device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = [ "subvol=/home" "noatime" "compress=zstd" "defaults"];
    };

  fileSystems."/nix" =
    { device = "/dev/disk/by-label/NIXROOT";
      fsType = "btrfs";
      options = [ "subvol=/nix" "noatime" "compress=zstd" "defaults"];
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-label/NIXBOOT";
      fsType = "vfat";
      options = [ "defaults" ];
      neededForBoot = true;
    };

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["subvol=/nix" "compress=zstd" "noatime" "defaults"];
    neededForBoot = true;
  };

  fileSystems."/.snapshots" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["subvol=/snapshots" "noatime" "compress=zstd" "defaults"];
  };

  fileSystems."/var/log" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["subvol=/log" "noatime" "compress=zstd" "defaults"];
    neededForBoot = true;
  };

  fileSystems."/persist" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["subvol=/persist" "noatime" "compress=zstd" "defaults"];
    neededForBoot = true;
  };

  fileSystems."/swap" = {
    device = "/dev/disk/by-label/NIXROOT";
    fsType = "btrfs";
    options = ["subvol=/swap" "noatime" "defaults"];
  };

  fileSystems."/tmp" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = ["mode=0755" "defaults"];
  };

  swapDevices = [{device = "/swap/swapfile";}];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.enp1s0.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlp0s20f3.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";

  hardware.enableAllFirmware = lib.mkDefault true;

  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableAllFirmware;
}

{inputs, ...}: {
  flake.nixosModules.boot = {
    config,
    pkgs,
    ...
  }: {
    config = {
      boot = {
        kernelPackages = pkgs.linuxPackages_cachyos;
        loader = {
          timeout = 3;
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
          systemd-boot.configurationLimit = 32;
        };
        kernel.sysctl = {
          "vm.swappiness" = 50;
        };
        # Reduce attack surface: obscure network protocols + rare/legacy filesystems
        # (kernel module auto-loading is a classic LPE vector)
        blacklistedKernelModules = [
          # Obscure network protocols
          "ax25"
          "netrom"
          "rose"

          # Old or rare or insufficiently audited filesystems
          "adfs"
          "affs"
          "bfs"
          "befs"
          "cramfs"
          "efs"
          "erofs"
          "exofs"
          "freevxfs"
          "f2fs"
          "hfs"
          "hpfs"
          "jfs"
          "minix"
          "nilfs2"
          "ntfs"
          "omfs"
          "qnx4"
          "qnx6"
          "sysv"
          "ufs"
        ];
        plymouth = {
          enable = true;
          theme = "bgrt";
          themePackages = with pkgs; [];
        };
      };
      services.scx.enable = true;
    };
  };
}

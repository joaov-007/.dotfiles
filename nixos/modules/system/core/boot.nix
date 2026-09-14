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

          # --- Kernel hardening (Lynis KRNL-6000) ---
          "kernel.kptr_restrict" = "2"; # hide kernel pointers even with CAP_SYSLOG
          "kernel.unprivileged_bpf_disabled" = "1"; # disable unprivileged BPF
          "kernel.io_uring_disabled" = "2"; # disable io_uring (major vuln source)
          "kernel.sysrq" = "0"; # disable magic SysRq key
          "fs.suid_dumpable" = "0"; # no SUID core dumps

          # --- Network hardening ---
          "net.core.bpf_jit_enable" = false; # mitigate JIT spray
          "net.ipv4.conf.all.rp_filter" = "1"; # strict reverse path filtering
          "net.ipv4.conf.all.accept_redirects" = false; # ignore ICMP redirects
          "net.ipv4.conf.all.send_redirects" = false; # don't send redirects
          "net.ipv4.conf.all.log_martians" = true; # log spoofed packets
          "net.ipv4.conf.default.accept_redirects" = false;
          "net.ipv4.conf.default.log_martians" = true;
          "net.ipv6.conf.all.accept_redirects" = false;
          "net.ipv6.conf.default.accept_redirects" = false;

          # --- Misc hardening ---
          "dev.tty.ldisc_autoload" = "0"; # prevent TIOCSETD exploit
          "fs.protected_fifos" = "2"; # harden FIFO creation
          "fs.protected_regular" = "2"; # harden regular file creation
        };
        # Reduce attack surface: obscure network protocols + rare/legacy filesystems
        # (kernel module auto-loading is a classic LPE vector)
        blacklistedKernelModules = [
          # Obscure network protocols
          "ax25"
          "netrom"
          "rose"
          "dccp"
          "sctp"
          "rds"
          "tipc"

          # USB storage (unplug attack vector — remove if you need USB drives)
          "usb-storage"

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
        # Kernel boot params — slab hardening, page randomization
        kernelParams = [
          "slab_nomerge" # don't merge slabs (reduces heap spray surface)
          "page_poison=1" # overwrite freed pages
          "page_alloc.shuffle=1" # randomize page allocator
          "debugfs=off" # disable debugfs
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

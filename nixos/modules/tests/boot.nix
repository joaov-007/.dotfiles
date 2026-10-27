{
  self,
  inputs,
  ...
}: {
  perSystem = {
    system,
    pkgs,
    ...
  }: {
    checks = {
      boot-health = pkgs.testers.nixosTest {
        name = "boot-health";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.boot];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("no failed systemd services"):
            machine.succeed("systemctl list-units --state=failed --no-pager | grep -v '0 loaded units'")
          with subtest("systemd targets reached"):
            machine.succeed("systemctl is-active multi-user.target")
        '';
      };

      kernel-hardening = pkgs.testers.nixosTest {
        name = "kernel-hardening";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.boot];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("kptr_restrict is set"):
            assert "2" == machine.succeed("sysctl -ne kernel.kptr_restrict").strip()
          with subtest("io_uring_disabled is set"):
            assert "2" == machine.succeed("sysctl -ne kernel.io_uring_disabled").strip()
          with subtest("sysrq is disabled"):
            assert "0" == machine.succeed("sysctl -ne kernel.sysrq").strip()
          with subtest("suid_dumpable is 0"):
            assert "0" == machine.succeed("sysctl -ne fs.suid_dumpable").strip()
          with subtest("bpf_jit_enable is disabled"):
            assert "0" == machine.succeed("sysctl -ne net.core.bpf_jit_enable").strip()
          with subtest("rp_filter is strict"):
            assert "1" == machine.succeed("sysctl -ne net.ipv4.conf.all.rp_filter").strip()
          with subtest("accept_redirects is disabled"):
            assert "0" == machine.succeed("sysctl -ne net.ipv4.conf.all.accept_redirects").strip()
          with subtest("log_martians is enabled"):
            assert "1" == machine.succeed("sysctl -ne net.ipv4.conf.all.log_martians").strip()
        '';
      };

      kernel-modules-blacklist = pkgs.testers.nixosTest {
        name = "kernel-modules-blacklist";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.boot];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("usb-storage is blacklisted"):
            machine.fail("modprobe usb-storage 2>&1 | grep -v 'not found'")
          with subtest("obscure network protocols are blacklisted"):
            machine.fail("modprobe ax25 2>&1 | grep -v 'not found'")
            machine.fail("modprobe dccp 2>&1 | grep -v 'not found'")
            machine.fail("modprobe sctp 2>&1 | grep -v 'not found'")
        '';
      };

      boot-time = pkgs.testers.nixosTest {
        name = "boot-time";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.boot];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("systemd-analyze works"):
            machine.succeed("systemd-analyze")
          with subtest("systemd-analyze blame works"):
            machine.succeed("systemd-analyze blame | head -5")
          with subtest("systemd-analyze critical-chain works"):
            machine.succeed("systemd-analyze critical-chain")
        '';
      };
    };
  };
}

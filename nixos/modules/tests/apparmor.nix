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
      apparmor-active = pkgs.testers.nixosTest {
        name = "apparmor-active";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.securityBase];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("AppArmor service is active"):
            machine.succeed("systemctl is-active apparmor.service")
          with subtest("securityfs is mounted"):
            machine.succeed("mountpoint -q /sys/kernel/security")
          with subtest("AppArmor profiles are listed"):
            machine.succeed("cat /sys/kernel/security/apparmor/profiles")
        '';
      };

      apparmor-not-aggressive = pkgs.testers.nixosTest {
        name = "apparmor-not-aggressive";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.securityBase];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("basic file operations work"):
            machine.succeed("touch /tmp/test-file")
            machine.succeed("echo hello > /tmp/test-file")
            machine.succeed("cat /tmp/test-file | grep -q hello")
            machine.succeed("rm /tmp/test-file")
          with subtest("user can run commands"):
            machine.succeed("su - root -c 'whoami'")
          with subtest("nix store is readable"):
            machine.succeed("ls /nix/store/ | head -1")
        '';
      };
    };
  };
}

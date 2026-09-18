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
      firewall-active = pkgs.testers.nixosTest {
        name = "firewall-active";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.securityBase];
          networking.firewall.allowedTCPPorts = [];
          networking.firewall.allowedUDPPorts = [];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("firewall service is active"):
            machine.succeed("systemctl is-active firewall.service")
        '';
      };

      security-posture = pkgs.testers.nixosTest {
        name = "security-posture";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [
            self.nixosModules.securityBase
            self.nixosModules.boot
          ];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("auditd is running"):
            machine.succeed("systemctl is-active auditd.service")
          with subtest("audit is enabled"):
            machine.succeed("auditctl -l")
          with subtest("AppArmor is enabled"):
            machine.succeed("aa-status")
          with subtest("login banner exists"):
            machine.succeed("cat /etc/issue | grep -q 'Authorized access only'")
        '';
      };

      user-isolation = pkgs.testers.nixosTest {
        name = "user-isolation";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.securityBase];
          security.sudo.enable = false;
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("sudo is disabled"):
            machine.fail("sudo -l 2>&1 | grep -v 'not found'")
          with subtest("doas is available"):
            machine.succeed("which doas")
        '';
      };
    };
  };
}

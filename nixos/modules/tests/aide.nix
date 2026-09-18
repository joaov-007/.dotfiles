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
      aide-integrity = pkgs.testers.nixosTest {
        name = "aide-integrity";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.aide];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("AIDE binary exists"):
            machine.succeed("which aide")
          with subtest("AIDE config exists"):
            machine.succeed("test -f /etc/aide.conf")
          with subtest("Initialize AIDE database"):
            machine.succeed("mkdir -p /var/lib/aide /var/log/aide")
            machine.succeed("aide -c /etc/aide.conf --init")
            machine.succeed("cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db")
          with subtest("Detect clean state"):
            machine.succeed("aide -c /etc/aide.conf --check")
          with subtest("Detect file modification"):
            machine.succeed("echo tampered > /etc/aide-test-tamper")
            machine.fail("aide -c /etc/aide.conf --check")
        '';
      };
    };
  };
}

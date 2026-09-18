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
      dns-resolution = pkgs.testers.nixosTest {
        name = "dns-resolution";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.bacon];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("systemd-resolved is active"):
            machine.succeed("systemctl is-active systemd-resolved")
          with subtest("DNS servers are configured"):
            machine.succeed("resolvectl status | grep -q 'DNS Servers'")
        '';
      };
    };
  };
}

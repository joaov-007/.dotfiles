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
      clamav-scanner = pkgs.testers.nixosTest {
        name = "clamav-scanner";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.clamav];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("ClamAV daemon is active"):
            machine.succeed("systemctl is-active clamd.service")
          with subtest("ClamAV updater is active"):
            machine.succeed("systemctl is-active freshclam.service")
          with subtest("clamdscan binary exists"):
            machine.succeed("which clamdscan")
        '';
      };
    };
  };
}

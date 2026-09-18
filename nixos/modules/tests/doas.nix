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
      doas-privilege = pkgs.testers.nixosTest {
        name = "doas-privilege";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.doas];
          users.users.testuser = {
            isNormalUser = true;
            extraGroups = ["wheel"];
          };
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("sudo is disabled"):
            machine.fail("sudo -l 2>&1 | grep -v 'not found'")
          with subtest("doas binary exists"):
            machine.succeed("which doas")
          with subtest("wheel user can doas without password"):
            machine.succeed("su - testuser -c 'doas -n true'")
          with subtest("non-wheel user cannot doas"):
            machine.succeed("useradd -m testnowheel")
            machine.fail("su - testnowheel -c 'doas -n true' 2>&1")
        '';
      };
    };
  };
}

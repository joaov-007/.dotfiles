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
      locale-timezone = pkgs.testers.nixosTest {
        name = "locale-timezone";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.locale];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("timezone is America/Sao_Paulo"):
            machine.succeed("timedatectl | grep -q 'Time zone: America/Sao_Paulo'")
          with subtest("default locale is en_US.UTF-8"):
            machine.succeed("localectl status | grep -q 'LANG=en_US.UTF-8'")
          with subtest("LC_TIME is pt_BR.UTF-8"):
            machine.succeed("localectl status | grep -q 'LC_TIME=pt_BR.UTF-8'")
          with subtest("timezone persists across reboot"):
            machine.shutdown()
            machine.wait_for_unit("multi-user.target")
            machine.succeed("timedatectl | grep -q 'Time zone: America/Sao_Paulo'")
        '';
      };
    };
  };
}

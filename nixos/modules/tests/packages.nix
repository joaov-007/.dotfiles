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
      package-smoke = pkgs.testers.nixosTest {
        name = "package-smoke";
        nodes.machine = {
          config,
          pkgs,
          ...
        }: {
          imports = [self.nixosModules.sopsNix];
          environment.systemPackages = with pkgs; [
            neovim
            git
            curl
            python3
            tree
            btop
          ];
        };
        testScript = ''
          machine.wait_for_unit("multi-user.target")
          with subtest("neovim works"):
            machine.succeed("nvim --version")
          with subtest("git works"):
            machine.succeed("git --version")
          with subtest("curl works"):
            machine.succeed("curl --version")
          with subtest("python3 works"):
            machine.succeed("python3 --version")
          with subtest("tree works"):
            machine.succeed("tree --version")
          with subtest("btop works"):
            machine.succeed("btop --version")
        '';
      };
    };
  };
}

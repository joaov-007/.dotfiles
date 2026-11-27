{self, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    home = self.nixosConfigurations.bacon.config.home-manager.users.joaov;
  in {
    # Pure config assertions: no NixOS closure build, so they can run on any
    # system supported by the pinned nixpkgs (x86_64-darwin was dropped in 26.11).
    checks = lib.optionalAttrs (system != "x86_64-darwin") {
      nvim = assert lib.asserts.assertMsg (home.home.file.".config/nvim".recursive == false)
      "Neovim configuration must be linked as an editable directory";
      assert lib.asserts.assertMsg (home.home.file.".config/nvim".source != null)
      "Joaov's editable Neovim configuration must be linked by Home Manager";
        pkgs.runCommand "nvim-check" {} "touch $out";
    };
  };
}

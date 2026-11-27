{self, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    home = self.nixosConfigurations.bacon.config.home-manager.users.joaov;
    installed = name:
      builtins.any (p: (p.pname or "") == name) home.home.packages;
    neovimInstalled =
      builtins.any (p: lib.hasInfix "neovim" (p.pname or "")) home.home.packages;
  in {
    # Pure config assertions: no NixOS closure build, so they can run on any
    # system supported by the pinned nixpkgs (x86_64-darwin was dropped in 26.11).
    checks = lib.optionalAttrs (system != "x86_64-darwin") {
      dev-tooling = assert lib.asserts.assertMsg neovimInstalled
      "Neovim must be available in the user profile";
      assert lib.asserts.assertMsg (installed "nixd")
      "nixd must be available for Nix language support";
      assert lib.asserts.assertMsg (installed "alejandra")
      "alejandra must be available for Nix formatting";
      assert lib.asserts.assertMsg (installed "lua-language-server")
      "lua-language-server must be available for Lua support";
      assert lib.asserts.assertMsg (installed "marksman")
      "marksman must be available for Markdown support";
      assert lib.asserts.assertMsg (installed "devenv")
      "devenv must be installed for development environments";
        pkgs.runCommand "dev-tooling-check" {} "touch $out";
    };
  };
}

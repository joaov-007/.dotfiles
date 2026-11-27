{self, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    self',
    ...
  }: let
    bacon = self.nixosConfigurations.bacon.config;
    home = bacon.home-manager.users.joaov;
  in {
    # Building these closures evaluates every imported NixOS and Home Manager
    # module, so package checks automatically cover newly added wrappers.
    checks =
      self'.packages
      # bacon's NixOS and Home Manager closures are x86_64-linux, so only
      # build them on that system. The pure assertion checks in the sibling
      # test modules run on every system the pinned nixpkgs still supports.
      // lib.optionalAttrs (system == "x86_64-linux") {
        nixos-bacon = bacon.system.build.toplevel;
        home-manager-joaov = home.home.activationPackage;
      };
  };
}

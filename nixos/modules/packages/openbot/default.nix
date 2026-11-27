{lib, ...}: {
  perSystem = {pkgs, ...}: {
    packages = lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
      openbot = pkgs.callPackage ./_package.nix {};
    };
  };
}

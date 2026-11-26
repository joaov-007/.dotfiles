{...}: {
  perSystem = {pkgs, ...}: {
    packages.pi-fff = pkgs.callPackage ./_package.nix {};
  };
}

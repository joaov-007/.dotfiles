{self, ...}: {
  flake.homeModules.yazi = {pkgs, ...}: {
    home.packages = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.yazi
    ];
  };
}

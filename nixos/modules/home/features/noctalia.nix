{
  inputs,
  self,
  ...
}: {
  flake.homeModules.noctalia = {pkgs, ...}: {
    imports = [
      inputs.noctalia.homeModules.default
    ];

    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      settings = self.noctaliaSettings;
    };
  };
}

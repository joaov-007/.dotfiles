{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.security = moduleWithSystem ({...}: let
    modules = with self.nixosModules; [
      securityBase
      aide
      clamav
    ];
  in {
    imports = modules;
  });
}

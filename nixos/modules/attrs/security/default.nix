{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.security = moduleWithSystem ({...}: let
    modules = with self.modules.nixos; [
      securityBase
      aide
      clamav
    ];
  in {
    imports = modules;
  });
}

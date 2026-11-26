{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.desktop = moduleWithSystem ({...}: let
    modules = with self.modules.nixos; [
      core
      stylix
      niri
      flatpak
    ];
  in {
    imports = modules;
  });
}

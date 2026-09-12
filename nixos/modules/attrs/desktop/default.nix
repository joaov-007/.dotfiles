{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.desktop = moduleWithSystem ({...}: let
    modules = with self.nixosModules; [
      core
      settings
      stylix
      niri
      flatpak
      kdeconnect
    ];
  in {
    imports = modules;
  });

}

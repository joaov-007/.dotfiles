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

  flake.homeModules.desktop = let
    modules = with self.homeModules; [
      common
      dev
      flatpak
      niri
      noctalia
      udiskie
      kdeconnect
      syncthing
    ];
  in {
    imports = modules;
  };
}

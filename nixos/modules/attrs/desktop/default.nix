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
      seahorse
    ];
  in {
    imports = modules;
  });

  flake.modules.homeManager.desktop = {...}: {
    imports = with self.modules.homeManager; [
      stylix
      niri
      noctalia
      udiskie
      xdg
    ];
  };
}

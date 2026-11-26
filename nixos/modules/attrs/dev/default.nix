{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.development = moduleWithSystem ({...}: {
    imports = with self.modules.nixos; [
      podman
      developmentTools
    ];
  });

  flake.modules.homeManager.development = moduleWithSystem ({...}: {
    imports = with self.modules.homeManager; [
      developmentTools
      shell
    ];
  });
}

{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.dev = moduleWithSystem ({...}: let
    modules = with self.nixosModules; [
      podman
    ];
  in {
    imports = modules;
  });

  flake.homeModules.dev = let
    modules = with self.homeModules; [
      git
      nvim
      shell
    ];
  in {
    imports = modules;
  };
}

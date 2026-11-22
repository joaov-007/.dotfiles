{
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.development = moduleWithSystem ({pkgs, ...}: let
    modules = with self.nixosModules; [
      podman
    ];
  in {
    imports = modules;
    environment.systemPackages = with pkgs; [
      opencode
      devenv
    ];
  });
}

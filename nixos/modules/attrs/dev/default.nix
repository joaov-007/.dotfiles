{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.development = moduleWithSystem ({pkgs, ...}: let
    modules = with self.modules.nixos; [
      podman
    ];
  in {
    imports = modules;
    environment.systemPackages = with pkgs; [
      opencode
      devenv
    ];
  });

  flake.modules.homeManager.development = {...}: {
    imports = with self.modules.homeManager; [
      git
      shell
    ];
  };
}

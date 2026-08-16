{...}: {
  flake.nixosModules.syncthing = {...}: {
  };

  flake.homeModules.syncthing = {...}: {
    services.syncthing.enable = true;
  };
}

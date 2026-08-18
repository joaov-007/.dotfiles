{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.homeManager = {...}: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    config = {
      home-manager = {
        useGlobalPkgs = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {inherit self inputs;};
        sharedModules = [
          self.homeModules.desktop
        ];
        users.joaov = self.homeModules.joaov;
      };
    };
  };
}

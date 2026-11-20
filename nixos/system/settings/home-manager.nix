{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.homeManager = {
    config,
    lib,
    ...
  }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    config = {
      home-manager = {
        useGlobalPkgs = true;
        backupFileExtension = "backup";
        extraSpecialArgs = {inherit self inputs;};
        sharedModules = [
          self.homeModules.default
        ];
        users.joaov = self.homeModules.joaov;
      };
    };
  };
}

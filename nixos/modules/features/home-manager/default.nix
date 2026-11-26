{
  inputs,
  self,
  ...
}: {
  flake.modules.nixos.home = {...}: {
    imports = [inputs.home-manager.nixosModules.home-manager];

    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      users.joaov = self.modules.homeManager.joaov;
    };
  };
}

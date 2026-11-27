{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.bacon = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {
      inherit inputs self;
    };

    modules = with self.modules.nixos; [
      bacon
      intelDrivers
      desktop
      development
      home
      nixIndexDatabase
      litellm
      doas
      security
    ];
  };
}

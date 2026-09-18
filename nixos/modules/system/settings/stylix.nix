{inputs, ...}: {
  flake.nixosModules.stylix = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      inputs.stylix.nixosModules.stylix
    ];

    assertions = [
      {
        assertion = config.stylix.polarity == "dark";
        message = "stylix polarity must be dark";
      }
    ];

    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
      polarity = "dark";
      targets.plymouth.enable = false;
      fonts = {
        sansSerif.name = "Inter";
        monospace.name = "JetBrainsMono Nerd Font";
      };
    };
  };
}

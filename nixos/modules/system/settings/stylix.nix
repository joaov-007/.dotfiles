{inputs, ...}: {
  flake.nixosModules.stylix = {pkgs, ...}: {
    imports = [
      inputs.stylix.nixosModules.stylix
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

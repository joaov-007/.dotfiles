{inputs, ...}: {
  flake.modules.nixos.stylix = {pkgs, ...}: let
    jetBrainsMono = {
      name = "JetBrainsMono Nerd Font";
      package = pkgs.nerd-fonts.jetbrains-mono;
    };
  in {
    imports = [
      inputs.stylix.nixosModules.stylix
    ];

    environment = {
      systemPackages = with pkgs; [
        bibata-cursors
        nwg-look
      ];
      variables.XCURSOR_THEME = "Bibata-Modern-Ice";
    };

    programs.dconf.enable = true;

    stylix = {
      enable = true;
      base16Scheme = "${pkgs.base16-schemes}/share/themes/tokyo-night-dark.yaml";
      polarity = "dark";
      targets.plymouth.enable = false;

      cursor = {
        name = "Bibata-Modern-Ice";
        package = pkgs.bibata-cursors;
        size = 20;
      };

      icons = {
        enable = true;
        package = pkgs.papirus-icon-theme;
        light = "Papirus-Light";
        dark = "Papirus-Dark";
      };

      fonts = {
        serif = jetBrainsMono;
        sansSerif = jetBrainsMono;
        monospace = jetBrainsMono;
        emoji = {
          name = "Noto Color Emoji";
          package = pkgs.noto-fonts-color-emoji;
        };
      };
    };
  };
}

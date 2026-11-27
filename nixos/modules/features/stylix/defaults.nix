{
  inputs,
  self,
  ...
}: {
  flake.desktopPalette = {
    base03 = "6b7396";
    base04 = "8a8fae";
    base08 = "f7768e";
    base0D = "2ac3de";
  };

  flake.modules.nixos.stylix = {pkgs, ...}: let
    inter = {
      name = "Inter";
      package = pkgs.inter;
    };
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
      override = self.desktopPalette;
      image = ./wallpaper.png;
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
        serif = inter;
        sansSerif = inter;
        monospace = jetBrainsMono;
        emoji = {
          name = "Noto Color Emoji";
          package = pkgs.noto-fonts-color-emoji;
        };
      };
    };
  };

  flake.modules.homeManager.stylix = {lib, ...}: {
    gtk = {
      theme.name = lib.mkForce "adw-gtk3-dark";
      gtk3.extraConfig."gtk-application-prefer-dark-theme" = true;
    };

    stylix.targets = {
      gtk.enable = true;
      noctalia.enable = true;
      qt.enable = true;
    };
  };
}

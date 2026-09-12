{inputs, ...}: {
  flake.homeModules.flatpak = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      inputs.nix-flatpak.homeManagerModules.nix-flatpak
    ];

    services.flatpak = {
      overrides = {
        global = {
          Context.filesystems = [
            "/nix/store:ro"
          ];
          Environment = {
            # flatpak: prefer-dark (ponytail: explicit color-scheme, polarity=dark only covers GTK theme)
            XDG_COLOR_SCHEME = "prefer-dark";
            GTK_COLOR_SCHEME = "prefer-dark";
          };
        };
      };
      packages = [
        "com.bitwarden.desktop"
        "com.calibre_ebook.calibre"
        "io.gitlab.librewolf-community"
        "md.obsidian.Obsidian"
        "net.ankiweb.Anki"
        "org.gnome.Calculator"
        "org.onlyoffice.desktopeditors"
      ];
      update.auto = {
        enable = true;
        onCalendar = "weekly";
      };
    };
  };
}

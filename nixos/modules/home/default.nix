{self, ...}: {
  # User: personal, per-user identity and preferences
  flake.homeModules.user = {
    imports = with self.homeModules; [
      joaov
    ];
  };

  # Global: shared across all hosts/users
  flake.homeModules.global = {
    imports = with self.homeModules; [
      common
      shell
      git
      xdg
      nvim
      yazi
      pi
    ];
  };

  # Desktop: GUI apps, window manager, display
  flake.homeModules.desktop = {
    imports = with self.homeModules; [
      niri
      noctalia
      flatpak
      kdeconnect
    ];
  };

  # System: services, automount, sync
  flake.homeModules.system = {
    imports = with self.homeModules; [
      udiskie
      syncthing
    ];
  };

  # Default: everything combined
  flake.homeModules.default = {
    imports = with self.homeModules; [
      user
      global
      desktop
      system
    ];
  };
}

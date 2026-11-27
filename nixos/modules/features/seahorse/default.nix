{...}: {
  flake.modules.nixos.seahorse = {
    # Seahorse ("Passwords and Keys") is the GNOME Keyring frontend.
    programs.seahorse.enable = true;

    # Keyring daemon holds the secrets Seahorse manages and backs the
    # org.freedesktop.secrets / xdg-desktop-portal secret service.
    services.gnome.gnome-keyring.enable = true;
  };
}

{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.flatpak = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      inputs.nix-flatpak.nixosModules.nix-flatpak
    ];

    services.flatpak.enable = true;

    security.apparmor = {
      packages = [pkgs.apparmor-profiles];
      policies = {
        flatpak = {
          state = "enforce";
          path = "${pkgs.apparmor-profiles}/etc/apparmor.d/flatpak";
        };
      };
    };

    xdg.portal = {
      enable = true;
      extraPortals = [pkgs.xdg-desktop-portal-gtk];
    };

    #    system.activationScripts.flatpak-binsh = ''
    #      [ -L /bin/sh ] || ln -s ${pkgs.bash}/bin/sh /bin/sh
    #    '';
  };
}

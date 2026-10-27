{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.flatpak = {
    pkgs,
    lib,
    config,
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

    assertions = [
      {
        assertion = config.services.flatpak.enable;
        message = "flatpak must be enabled";
      }
      {
        assertion = config.xdg.portal.enable;
        message = "xdg portal must be enabled for flatpak";
      }
      {
        assertion = builtins.length config.xdg.portal.extraPortals > 0;
        message = "xdg portal must have extra portals configured";
      }
      {
        assertion = config.security.apparmor.policies.flatpak.state == "enforce";
        message = "flatpak apparmor profile must be in enforce mode";
      }
    ];
  };
}

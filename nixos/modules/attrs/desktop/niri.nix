{
  inputs,
  self,
  moduleWithSystem,
  ...
}: {
  flake.nixosModules.niri = {
    pkgs,
    lib,
    ...
  }: {
    imports = [
      inputs.noctalia.nixosModules.default
    ];

    programs.niri = {
      enable = true;
      package = self.packages.${pkgs.stdenv.hostPlatform.system}.niri;
    };

    programs.noctalia = {
      enable = true;
      recommendedServices.enable = true;
      systemd.enable = true;
    };

    services.displayManager.defaultSession = lib.mkForce "niri";
  };

  perSystem = moduleWithSystem (
    {
      pkgs,
      self',
      ...
    }: {
      packages.niri = inputs.wrappers-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = {
          layout = {
            gaps = 8;
            background-color = "transparent";
          };
          input = {
            focus-follows-mouse = _: {};
            touchpad = {
              tap = _: {};
            };
          };
          environment."NIXOS_OZONE_WL" = "1";
          spawn-at-startup = [
            (pkgs.lib.getExe self'.packages.noctalia)
          ];
          xwayland-satellite.path = pkgs.lib.getExe pkgs.xwayland-satellite;
          binds = self.niriKeybinds;
          window-rules = [
            {
              matches = [
                {
                  "is-active" = false;
                }
              ];
              opacity = 0.95;
              draw-border-with-background = false;
            }
            {
              matches = [
                {
                  app-id = "alacritty";
                }
              ];
              opacity = 0.92;
              draw-border-with-background = false;
            }
          ];
          extraConfig = ''
            window-rule {
              geometry-corner-radius 20
              clip-to-geometry true
            }
            window-rule {
              match app-id="dev.noctalia.Noctalia"
              open-floating true
              default-column-width { fixed 1080; }
              default-window-height { fixed 920; }
            }
            debug {
              honor-xdg-activation-with-invalid-serial
            }
            layer-rule {
              match namespace="^noctalia-backdrop"
              place-within-backdrop true
            }
            blur {
              passes 2
              offset 3.0
              noise 0.03
              saturation 1.0
            }
            window-rule {
              background-effect {
                blur true
              }
            }
            layer-rule {
              match namespace="^noctalia-(bar-[^\"]+|notification|dock|panel|attached-panel|osd)$"
              background-effect {
                xray false
              }
            }
            layer-rule {
              match namespace="noctalia-window-switcher"
              background-effect {
                blur true
                xray false
              }
            }
          '';
        };
      };
    }
  );
}

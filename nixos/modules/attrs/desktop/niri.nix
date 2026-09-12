{
  inputs,
  self,
  moduleWithSystem,
  ...
}: let
  # wrapper-modules DSL: "key" = _: { props = {...}; content = {...}; }
  mkBind = title: content: _: {
    props."hotkey-overlay-title" = title;
    content = content;
  };
  mkAction = title: name: mkBind title {${name} = _: {};};
  mkSpawn = title: argv: mkBind title {spawn = argv;};
  mkSpawnSh = title: cmd: mkBind title {"spawn-sh" = cmd;};
  mkLocked = title: cmd: _: {
    props."allow-when-locked" = true;
    props."hotkey-overlay-title" = title;
    content."spawn-sh" = cmd;
  };

  wsBinds = builtins.listToAttrs (builtins.concatLists (builtins.genList (i: let
      n = toString (i + 1);
    in [
      {
        name = "Mod+${n}";
        value = mkBind "Focus Workspace ${n}" {"focus-workspace" = [(i + 1)];};
      }
      {
        name = "Mod+Ctrl+${n}";
        value = mkBind "Move Column to Workspace ${n}" {"move-column-to-workspace" = [(i + 1)];};
      }
    ])
    9));

  mediaBinds = builtins.listToAttrs (map ({
      key,
      title,
      cmd,
    }: {
      name = key;
      value = mkLocked title cmd;
    }) [
      {
        key = "XF86AudioRaiseVolume";
        title = "Volume Up";
        cmd = "noctalia msg volume-up";
      }
      {
        key = "XF86AudioLowerVolume";
        title = "Volume Down";
        cmd = "noctalia msg volume-down";
      }
      {
        key = "XF86AudioMute";
        title = "Volume Mute";
        cmd = "noctalia msg volume-mute";
      }
      {
        key = "XF86MonBrightnessUp";
        title = "Brightness Up";
        cmd = "noctalia msg brightness-up";
      }
      {
        key = "XF86MonBrightnessDown";
        title = "Brightness Down";
        cmd = "noctalia msg brightness-down";
      }
      {
        key = "XF86AudioPlay";
        title = "Media Toggle";
        cmd = "noctalia msg media toggle";
      }
      {
        key = "XF86AudioStop";
        title = "Media Stop";
        cmd = "noctalia msg media stop";
      }
      {
        key = "XF86AudioPrev";
        title = "Media Previous";
        cmd = "noctalia msg media previous";
      }
      {
        key = "XF86AudioNext";
        title = "Media Next";
        cmd = "noctalia msg media next";
      }
      {
        key = "XF86AudioMicMute";
        title = "Toggle Mic Mute";
        cmd = "noctalia msg mic-mute";
      }
    ]);

  binds = {
    # launcher / panels / windows
    "Mod+O" = mkAction "Toggle Window Opacity" "toggle-window-rule-opacity";
    "Mod+Space" = mkSpawnSh "Run an Application: Launcher" "noctalia msg panel-toggle launcher";
    "Mod+S" = mkSpawnSh "Toggle Control Center" "noctalia msg panel-toggle control-center";
    "Mod+Comma" = mkSpawnSh "Toggle Settings" "noctalia msg settings-toggle";
    "Alt+Tab" = mkSpawnSh "Window Switcher" "noctalia msg window-switcher";
    "Mod+D" = mkSpawnSh "Run an Application: Launcher" "noctalia msg panel-toggle launcher";
    "Mod+Shift+Space" = mkSpawnSh "Toggle Clipboard History" "noctalia msg panel-toggle clipboard";
    "Mod+Ctrl+W" = mkSpawnSh "Browse Wallpapers" "noctalia msg panel-toggle wallpaper";
    "Mod+Ctrl+S" = mkSpawnSh "Session Menu" "noctalia msg panel-toggle session";
    "Mod+F1" = mkSpawnSh "Keybind Cheatsheet" "noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet";
    "Super+Alt+L" = mkSpawnSh "Lock the Screen" "noctalia msg session lock";

    # focus / move columns & windows
    "Mod+H" = mkAction "Focus Column Left" "focus-column-left";
    "Mod+J" = mkAction "Focus Window Down" "focus-window-down";
    "Mod+K" = mkAction "Focus Window Up" "focus-window-up";
    "Mod+L" = mkAction "Focus Column Right" "focus-column-right";
    "Mod+Shift+H" = mkAction "Move Column Left" "move-column-left";
    "Mod+Shift+J" = mkAction "Move Window Down" "move-window-down";
    "Mod+Shift+K" = mkAction "Move Window Up" "move-window-up";
    "Mod+Shift+L" = mkAction "Move Column Right" "move-column-right";
    "Mod+Shift+Slash" = mkAction "Show Hotkey Overlay" "show-hotkey-overlay";
    "Mod+Home" = mkAction "Focus First Column" "focus-column-first";
    "Mod+End" = mkAction "Focus Last Column" "focus-column-last";
    "Mod+Ctrl+Home" = mkAction "Move Column to First" "move-column-to-first";
    "Mod+Ctrl+End" = mkAction "Move Column to Last" "move-column-to-last";
    "Mod+BracketLeft" = mkAction "Consume or Expel Window Left" "consume-or-expel-window-left";
    "Mod+BracketRight" = mkAction "Consume or Expel Window Right" "consume-or-expel-window-right";
    "Mod+Period" = mkAction "Expel Window from Column" "expel-window-from-column";

    # workspace navigation
    "Mod+U" = mkAction "Focus Workspace Down" "focus-workspace-down";
    "Mod+I" = mkAction "Focus Workspace Up" "focus-workspace-up";
    "Mod+Shift+U" = mkAction "Move Workspace Down" "move-workspace-down";
    "Mod+Shift+I" = mkAction "Move Workspace Up" "move-workspace-up";
    "Mod+Ctrl+U" = mkAction "Move Column to Workspace Down" "move-column-to-workspace-down";
    "Mod+Ctrl+I" = mkAction "Move Column to Workspace Up" "move-column-to-workspace-up";
    "Mod+Page_Down" = mkAction "Focus Workspace Down" "focus-workspace-down";
    "Mod+Page_Up" = mkAction "Focus Workspace Up" "focus-workspace-up";
    "Mod+Tab" = mkAction "Focus Previous Workspace" "focus-workspace-previous";

    # window actions
    "Mod+Q" = mkAction "Close Window" "close-window";
    "Mod+Shift+Q" = _: {
      props.repeat = false;
      props."hotkey-overlay-title" = "Quit Niri";
      content.quit = _: {};
    };
    "Mod+Escape" = mkAction "Toggle Shortcuts Inhibit" "toggle-keyboard-shortcuts-inhibit";
    "Mod+V" = mkAction "Toggle Window Floating" "toggle-window-floating";
    "Mod+Shift+V" = mkAction "Switch Focus Between Floating and Tiling" "switch-focus-between-floating-and-tiling";
    "Mod+W" = mkAction "Toggle Column Tabbed Display" "toggle-column-tabbed-display";
    "Mod+F" = mkAction "Maximize Column" "maximize-column";
    "Mod+Shift+F" = mkAction "Fullscreen Window" "fullscreen-window";
    "Mod+M" = mkAction "Maximize Window to Edges" "maximize-window-to-edges";
    "Mod+Ctrl+F" = mkAction "Expand Column to Available Width" "expand-column-to-available-width";
    "Mod+C" = mkAction "Center Column" "center-column";
    "Mod+Ctrl+C" = mkAction "Center Visible Columns" "center-visible-columns";
    "Mod+R" = mkAction "Switch Preset Column Width" "switch-preset-column-width";
    "Mod+Shift+R" = mkAction "Switch Preset Column Width Back" "switch-preset-column-width-back";
    "Mod+Ctrl+Shift+R" = mkAction "Switch Preset Window Height" "switch-preset-window-height";
    "Mod+Ctrl+R" = mkAction "Reset Window Height" "reset-window-height";

    # resize
    "Mod+Minus" = mkBind "Shrink Column" {"set-column-width" = ["-10%"];};
    "Mod+Equal" = mkBind "Grow Column" {"set-column-width" = ["+10%"];};
    "Mod+Shift+Minus" = mkBind "Shrink Window Height" {"set-window-height" = ["-10%"];};
    "Mod+Shift+Equal" = mkBind "Grow Window Height" {"set-window-height" = ["+10%"];};

    # apps
    "Mod+T" = mkSpawn "Open a Terminal: alacritty" ["alacritty"];
    "Mod+B" = mkSpawn "Open a Browser: LibreWolf" ["flatpak" "run" "io.gitlab.librewolf-community"];
    "Mod+E" = mkSpawn "Open File Manager: Nautilus" ["nautilus"];

    # screenshots
    "Print" = mkAction "Screenshot" "screenshot";
    "Ctrl+Print" = mkAction "Screenshot Screen" "screenshot-screen";
    "Alt+Print" = mkAction "Screenshot Window" "screenshot-window";

    # theme / wallpaper / notifications
    "Mod+Shift+T" = mkSpawnSh "Toggle Dark/Light Theme" "niri msg action do-screen-transition; noctalia msg theme-mode-toggle";
    "Mod+Shift+W" = mkSpawnSh "Next Wallpaper" "noctalia msg wallpaper-next";
    "Mod+N" = mkSpawnSh "Toggle Night Light" "noctalia msg nightlight-toggle";
    "Mod+Shift+N" = mkSpawnSh "Toggle Do Not Disturb" "noctalia msg notification-dnd-toggle";
    "Mod+Shift+D" = mkSpawnSh "Toggle Dock" "noctalia msg dock-toggle";
  }
  // wsBinds
  // mediaBinds;
in {
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

    services.displayManager.ly.enable = true;
    services.displayManager.defaultSession = lib.mkForce "niri";
  };

  perSystem = moduleWithSystem (
    {
      pkgs,
      self',
      ...
    }: {
      packages.noctalia =
        (inputs.wrappers-modules.lib.wrapModule {
          imports = [inputs.wrappers-modules.wrapperModules.noctalia-shell];
          inherit pkgs;
          package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
          settings = {
            shell.niri_overview_type_to_launch_enabled = true;
            shell.launch_apps_as_systemd_services = true;
            theme.templates = {
              enable_builtin_templates = true;
              enable_community_templates = true;
              community_ids = ["obsidian"];
            };
          };
        }).wrapper;

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
          inherit binds;
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

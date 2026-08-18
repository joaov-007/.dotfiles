{...}: let
  # wrapper-modules DSL: "key" = _: { props = {...}; content = {...}; }
  mkBind = title: content: _: {
    props."hotkey-overlay-title" = title;
    content = content;
  };
  # no-arg niri action
  mkAction = title: name: mkBind title {${name} = _: {};};
  # spawn argv (no shell)
  mkSpawn = title: argv: mkBind title {spawn = argv;};
  # spawn through sh -c
  mkSpawnSh = title: cmd: mkBind title {"spawn-sh" = cmd;};
  # media/volume keys, also work while locked
  mkLocked = title: cmd: _: {
    props."allow-when-locked" = true;
    props."hotkey-overlay-title" = title;
    content."spawn-sh" = cmd;
  };

  # workspaces 1-9: focus + move column to
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

  # media / volume / brightness keys
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
in {
  flake.niriKeybinds =
    {
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
}

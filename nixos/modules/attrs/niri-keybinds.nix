{...}: {
  flake.niriKeybinds = {
    "Mod+O" = _: {
      props."hotkey-overlay-title" = "Toggle Window Opacity";
      content."toggle-window-rule-opacity" = _: {};
    };
    "Mod+Space" = _: {
      props."hotkey-overlay-title" = "Run an Application: Launcher";
      content."spawn-sh" = "noctalia msg panel-toggle launcher";
    };
    "Mod+S" = _: {
      props."hotkey-overlay-title" = "Toggle Control Center";
      content."spawn-sh" = "noctalia msg panel-toggle control-center";
    };
    "Mod+Comma" = _: {
      props."hotkey-overlay-title" = "Toggle Settings";
      content."spawn-sh" = "noctalia msg settings-toggle";
    };
    "Alt+Tab" = _: {
      props."hotkey-overlay-title" = "Window Switcher";
      content."spawn-sh" = "noctalia msg window-switcher";
    };
    "XF86AudioRaiseVolume" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Volume Up";
      content."spawn-sh" = "noctalia msg volume-up";
    };
    "XF86AudioLowerVolume" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Volume Down";
      content."spawn-sh" = "noctalia msg volume-down";
    };
    "XF86AudioMute" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Volume Mute";
      content."spawn-sh" = "noctalia msg volume-mute";
    };
    "XF86MonBrightnessUp" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Brightness Up";
      content."spawn-sh" = "noctalia msg brightness-up";
    };
    "XF86MonBrightnessDown" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Brightness Down";
      content."spawn-sh" = "noctalia msg brightness-down";
    };
    "Mod+H" = _: {
      props."hotkey-overlay-title" = "Focus Column Left";
      content."focus-column-left" = _: {};
    };
    "Mod+J" = _: {
      props."hotkey-overlay-title" = "Focus Window Down";
      content."focus-window-down" = _: {};
    };
    "Mod+K" = _: {
      props."hotkey-overlay-title" = "Focus Window Up";
      content."focus-window-up" = _: {};
    };
    "Mod+L" = _: {
      props."hotkey-overlay-title" = "Focus Column Right";
      content."focus-column-right" = _: {};
    };
    "Mod+Shift+H" = _: {
      props."hotkey-overlay-title" = "Move Column Left";
      content."move-column-left" = _: {};
    };
    "Mod+Shift+J" = _: {
      props."hotkey-overlay-title" = "Move Window Down";
      content."move-window-down" = _: {};
    };
    "Mod+Shift+K" = _: {
      props."hotkey-overlay-title" = "Move Window Up";
      content."move-window-up" = _: {};
    };
    "Mod+Shift+L" = _: {
      props."hotkey-overlay-title" = "Move Column Right";
      content."move-column-right" = _: {};
    };
    "Mod+Shift+Slash" = _: {
      props."hotkey-overlay-title" = "Show Hotkey Overlay";
      content."show-hotkey-overlay" = _: {};
    };
    "Mod+T" = _: {
      props."hotkey-overlay-title" = "Open a Terminal: alacritty";
      content.spawn = ["alacritty"];
    };
    "Mod+B" = _: {
      props."hotkey-overlay-title" = "Open a Browser: LibreWolf";
      content.spawn = ["flatpak" "run" "io.gitlab.librewolf-community"];
    };
    "Mod+E" = _: {
      props."hotkey-overlay-title" = "Open File Manager: Nautilus";
      content.spawn = ["nautilus"];
    };
    "Mod+Escape" = _: {
      props."hotkey-overlay-title" = "Toggle Shortcuts Inhibit";
      content."toggle-keyboard-shortcuts-inhibit" = _: {};
    };
    "Mod+Shift+T" = _: {
      props."hotkey-overlay-title" = "Toggle Dark/Light Theme";
      content."spawn-sh" = "niri msg action do-screen-transition; noctalia msg theme-mode-toggle";
    };
    "Mod+Shift+W" = _: {
      props."hotkey-overlay-title" = "Next Wallpaper";
      content."spawn-sh" = "noctalia msg wallpaper-next";
    };
    "Mod+N" = _: {
      props."hotkey-overlay-title" = "Toggle Night Light";
      content."spawn-sh" = "noctalia msg nightlight-toggle";
    };
    "Mod+Shift+N" = _: {
      props."hotkey-overlay-title" = "Toggle Do Not Disturb";
      content."spawn-sh" = "noctalia msg notification-dnd-toggle";
    };
    "Mod+Shift+D" = _: {
      props."hotkey-overlay-title" = "Toggle Dock";
      content."spawn-sh" = "noctalia msg dock-toggle";
    };
    "Mod+D" = _: {
      props."hotkey-overlay-title" = "Run an Application: Launcher";
      content."spawn-sh" = "noctalia msg panel-toggle launcher";
    };
    "Mod+Shift+Space" = _: {
      props."hotkey-overlay-title" = "Toggle Clipboard History";
      content."spawn-sh" = "noctalia msg panel-toggle clipboard";
    };
    "Mod+Ctrl+W" = _: {
      props."hotkey-overlay-title" = "Browse Wallpapers";
      content."spawn-sh" = "noctalia msg panel-toggle wallpaper";
    };
    "Mod+Ctrl+S" = _: {
      props."hotkey-overlay-title" = "Session Menu";
      content."spawn-sh" = "noctalia msg panel-toggle session";
    };
    "Mod+F1" = _: {
      props."hotkey-overlay-title" = "Keybind Cheatsheet";
      content."spawn-sh" = "noctalia msg panel-toggle kenn/keybind-cheatsheet:cheatsheet";
    };
    "Super+Alt+L" = _: {
      props."hotkey-overlay-title" = "Lock the Screen";
      content."spawn-sh" = "noctalia msg session lock";
    };
    "Mod+Q" = _: {
      props."hotkey-overlay-title" = "Close Window";
      content."close-window" = _: {};
    };
    "Mod+Shift+Q" = _: {
      props.repeat = false;
      props."hotkey-overlay-title" = "Quit Niri";
      content.quit = _: {};
    };
    "Mod+U" = _: {
      props."hotkey-overlay-title" = "Focus Workspace Down";
      content."focus-workspace-down" = _: {};
    };
    "Mod+I" = _: {
      props."hotkey-overlay-title" = "Focus Workspace Up";
      content."focus-workspace-up" = _: {};
    };
    "Mod+Shift+U" = _: {
      props."hotkey-overlay-title" = "Move Workspace Down";
      content."move-workspace-down" = _: {};
    };
    "Mod+Shift+I" = _: {
      props."hotkey-overlay-title" = "Move Workspace Up";
      content."move-workspace-up" = _: {};
    };
    "Mod+Ctrl+U" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace Down";
      content."move-column-to-workspace-down" = _: {};
    };
    "Mod+Ctrl+I" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace Up";
      content."move-column-to-workspace-up" = _: {};
    };
    "Mod+Page_Down" = _: {
      props."hotkey-overlay-title" = "Focus Workspace Down";
      content."focus-workspace-down" = _: {};
    };
    "Mod+Page_Up" = _: {
      props."hotkey-overlay-title" = "Focus Workspace Up";
      content."focus-workspace-up" = _: {};
    };
    "Mod+Tab" = _: {
      props."hotkey-overlay-title" = "Focus Previous Workspace";
      content."focus-workspace-previous" = _: {};
    };
    "Mod+1" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 1";
      content."focus-workspace" = [1];
    };
    "Mod+2" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 2";
      content."focus-workspace" = [2];
    };
    "Mod+3" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 3";
      content."focus-workspace" = [3];
    };
    "Mod+4" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 4";
      content."focus-workspace" = [4];
    };
    "Mod+5" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 5";
      content."focus-workspace" = [5];
    };
    "Mod+6" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 6";
      content."focus-workspace" = [6];
    };
    "Mod+7" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 7";
      content."focus-workspace" = [7];
    };
    "Mod+8" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 8";
      content."focus-workspace" = [8];
    };
    "Mod+9" = _: {
      props."hotkey-overlay-title" = "Focus Workspace 9";
      content."focus-workspace" = [9];
    };
    "Mod+Ctrl+1" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 1";
      content."move-column-to-workspace" = [1];
    };
    "Mod+Ctrl+2" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 2";
      content."move-column-to-workspace" = [2];
    };
    "Mod+Ctrl+3" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 3";
      content."move-column-to-workspace" = [3];
    };
    "Mod+Ctrl+4" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 4";
      content."move-column-to-workspace" = [4];
    };
    "Mod+Ctrl+5" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 5";
      content."move-column-to-workspace" = [5];
    };
    "Mod+Ctrl+6" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 6";
      content."move-column-to-workspace" = [6];
    };
    "Mod+Ctrl+7" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 7";
      content."move-column-to-workspace" = [7];
    };
    "Mod+Ctrl+8" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 8";
      content."move-column-to-workspace" = [8];
    };
    "Mod+Ctrl+9" = _: {
      props."hotkey-overlay-title" = "Move Column to Workspace 9";
      content."move-column-to-workspace" = [9];
    };
    "Mod+Home" = _: {
      props."hotkey-overlay-title" = "Focus First Column";
      content."focus-column-first" = _: {};
    };
    "Mod+End" = _: {
      props."hotkey-overlay-title" = "Focus Last Column";
      content."focus-column-last" = _: {};
    };
    "Mod+Ctrl+Home" = _: {
      props."hotkey-overlay-title" = "Move Column to First";
      content."move-column-to-first" = _: {};
    };
    "Mod+Ctrl+End" = _: {
      props."hotkey-overlay-title" = "Move Column to Last";
      content."move-column-to-last" = _: {};
    };
    "Mod+BracketLeft" = _: {
      props."hotkey-overlay-title" = "Consume or Expel Window Left";
      content."consume-or-expel-window-left" = _: {};
    };
    "Mod+BracketRight" = _: {
      props."hotkey-overlay-title" = "Consume or Expel Window Right";
      content."consume-or-expel-window-right" = _: {};
    };
    "Mod+Period" = _: {
      props."hotkey-overlay-title" = "Expel Window from Column";
      content."expel-window-from-column" = _: {};
    };
    "Mod+R" = _: {
      props."hotkey-overlay-title" = "Switch Preset Column Width";
      content."switch-preset-column-width" = _: {};
    };
    "Mod+Shift+R" = _: {
      props."hotkey-overlay-title" = "Switch Preset Column Width Back";
      content."switch-preset-column-width-back" = _: {};
    };
    "Mod+Ctrl+Shift+R" = _: {
      props."hotkey-overlay-title" = "Switch Preset Window Height";
      content."switch-preset-window-height" = _: {};
    };
    "Mod+Ctrl+R" = _: {
      props."hotkey-overlay-title" = "Reset Window Height";
      content."reset-window-height" = _: {};
    };
    "Mod+F" = _: {
      props."hotkey-overlay-title" = "Maximize Column";
      content."maximize-column" = _: {};
    };
    "Mod+Shift+F" = _: {
      props."hotkey-overlay-title" = "Fullscreen Window";
      content."fullscreen-window" = _: {};
    };
    "Mod+M" = _: {
      props."hotkey-overlay-title" = "Maximize Window to Edges";
      content."maximize-window-to-edges" = _: {};
    };
    "Mod+Ctrl+F" = _: {
      props."hotkey-overlay-title" = "Expand Column to Available Width";
      content."expand-column-to-available-width" = _: {};
    };
    "Mod+C" = _: {
      props."hotkey-overlay-title" = "Center Column";
      content."center-column" = _: {};
    };
    "Mod+Ctrl+C" = _: {
      props."hotkey-overlay-title" = "Center Visible Columns";
      content."center-visible-columns" = _: {};
    };
    "Mod+Minus" = _: {
      props."hotkey-overlay-title" = "Shrink Column";
      content."set-column-width" = ["-10%"];
    };
    "Mod+Equal" = _: {
      props."hotkey-overlay-title" = "Grow Column";
      content."set-column-width" = ["+10%"];
    };
    "Mod+Shift+Minus" = _: {
      props."hotkey-overlay-title" = "Shrink Window Height";
      content."set-window-height" = ["-10%"];
    };
    "Mod+Shift+Equal" = _: {
      props."hotkey-overlay-title" = "Grow Window Height";
      content."set-window-height" = ["+10%"];
    };
    "Mod+V" = _: {
      props."hotkey-overlay-title" = "Toggle Window Floating";
      content."toggle-window-floating" = _: {};
    };
    "Mod+Shift+V" = _: {
      props."hotkey-overlay-title" = "Switch Focus Between Floating and Tiling";
      content."switch-focus-between-floating-and-tiling" = _: {};
    };
    "Mod+W" = _: {
      props."hotkey-overlay-title" = "Toggle Column Tabbed Display";
      content."toggle-column-tabbed-display" = _: {};
    };
    "Print" = _: {
      props."hotkey-overlay-title" = "Screenshot";
      content.screenshot = _: {};
    };
    "Ctrl+Print" = _: {
      props."hotkey-overlay-title" = "Screenshot Screen";
      content."screenshot-screen" = _: {};
    };
    "Alt+Print" = _: {
      props."hotkey-overlay-title" = "Screenshot Window";
      content."screenshot-window" = _: {};
    };
    "XF86AudioPlay" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Media Toggle";
      content."spawn-sh" = "noctalia msg media toggle";
    };
    "XF86AudioStop" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Media Stop";
      content."spawn-sh" = "noctalia msg media stop";
    };
    "XF86AudioPrev" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Media Previous";
      content."spawn-sh" = "noctalia msg media previous";
    };
    "XF86AudioNext" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Media Next";
      content."spawn-sh" = "noctalia msg media next";
    };
    "XF86AudioMicMute" = _: {
      props."allow-when-locked" = true;
      props."hotkey-overlay-title" = "Toggle Mic Mute";
      content."spawn-sh" = "noctalia msg mic-mute";
    };
  };
}

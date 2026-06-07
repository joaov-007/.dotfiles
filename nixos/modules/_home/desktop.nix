{
  pkgs,
  config,
  ...
}: {
  # Desktop applications that should be available in the GUI environment
  # These are typically larger GUI applications that users want in their desktop environment

  # Note: For actual GUI launching, you might need to ensure these are in your desktop environment's menu
  # or create desktop files. This simply makes them available in the user's environment.

  home.packages = with pkgs; [
    kitty
    obsidian
    calibre
    gnome-monitor-config
  ];

  home.file.".config/kitty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.dotfiles/modules/others/kitty";
    recursive = true;
    force = true;
  };
}

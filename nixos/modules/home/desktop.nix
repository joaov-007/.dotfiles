{pkgs, ...}: {
  # Desktop applications that should be available in the GUI environment
  # These are typically larger GUI applications that users want in their desktop environment
  
  # Note: For actual GUI launching, you might need to ensure these are in your desktop environment's menu
  # or create desktop files. This simply makes them available in the user's environment.
  
  home.packages = with pkgs; [
    # Already in cli.nix but keeping for completeness if we want to separate concerns
    obsidian
    calibre
    
    # Additional desktop apps can be added here
    # firefox
    # thunderbird
    # libreoffice
    # gimp
    # inkscape
    # vlc
  ];
}
{...}: {
  flake.homeModules.niri = {pkgs, ...}: {
    programs.alacritty.enable = true;

    home.packages = [pkgs.nautilus];
  };
}

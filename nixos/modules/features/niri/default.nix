{...}: {
  flake.modules.homeManager.niri = {pkgs, ...}: {
    programs.alacritty.enable = true;

    home.packages = [pkgs.nautilus];
  };
}

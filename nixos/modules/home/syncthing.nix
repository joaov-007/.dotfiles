{ config, pkgs, ... }:

{
  services.syncthing.enable = true;
  # home.packages = with pkgs; [
  #   synththing
  # ];
}

{ pkgs, ... }: {
fonts.packages = with pkgs.nerd-fonts; [
  fira-code
  droid-sans-mono
  jetbrains-mono
  iosevka
  caskaydia-cove
];
}

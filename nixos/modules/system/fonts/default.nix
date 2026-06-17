{...}: {
  flake.nixosModules.fonts = {pkgs, ...}: {
    fonts.packages = with pkgs; [
      # Nerd Fonts
      nerd-fonts.iosevka
      nerd-fonts.jetbrains-mono
      nerd-fonts.meslo-lg
      nerd-fonts.fira-code
      nerd-fonts.hack
      # Microsoft
      corefonts
      vista-fonts
      carlito
      caladea
      # Essential
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
      dejavu_fonts
      liberation_ttf
      # Cool / trendy
      monaspace
      maple-mono.NF
      cascadia-code
      fira-code
      inter
      ibm-plex
      victor-mono
    ];
    nixpkgs.config.allowUnfreePredicate = pkg: (builtins.elem (pkg.pname or pkg.name) [
      "corefonts"
      "vista-fonts"
    ]);
  };
}

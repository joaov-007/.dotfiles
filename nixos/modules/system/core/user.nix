{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.user = {
    pkgs,
    lib,
    ...
  }: {
    users.mutableUsers = false;

    users.users.root.hashedPassword = "$y$j9T$.ISCl/aQ0j7Q6YeiP7ZXI0$DoZXwhbkD35LmKsHIn4/XIraODuDA02SO7OHKcumuq4";
    users.users.joaov = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$Uhi/1Es0cg1sswwUBGnuh/$KcWOw417vWeHjNEd17Xq4oDZ/3iuP7kXcegB16CyVdD";
      extraGroups = ["wheel" "networkmanager" "render" "input" "adm" "audio" "video" "dialout" "plugdev" "i2c" "fuse" "dialout" "gpio" "spi" "netdev" "games" "cdrom"];
      subUidRanges = [
        {
          startUid = 100000;
          count = 65536;
        }
      ];
      subGidRanges = [
        {
          startGid = 100000;
          count = 65536;
        }
      ];
      packages = with pkgs; [
        tree
        btop
        neovim
        git
        nodejs
        python3
      ];
    };

  };
}

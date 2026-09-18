{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.user = {
    config,
    pkgs,
    lib,
    ...
  }: {
    users.mutableUsers = false;

    users.users.root.hashedPassword = "$y$j9T$gKL9kJ16d65/w/qGRowu.1$w1/cGE91HgV6ZrQBwtJKpIZSjeDmTZLFRxrQje9wMD.";
    users.users.joaov = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$gKL9kJ16d65/w/qGRowu.1$w1/cGE91HgV6ZrQBwtJKpIZSjeDmTZLFRxrQje9wMD.";
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

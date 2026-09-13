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

    age.secrets = {
      root-pw-hash = {
        rekeyFile = self + "/secrets/root-pw-hash.age";
        owner = "root";
      };
      joaov-pw-hash = {
        rekeyFile = self + "/secrets/joaov-pw-hash.age";
        owner = "root";
      };
    };

    users.users.root.hashedPasswordFile = config.age.secrets.root-pw-hash.path;
    users.users.joaov = {
      isNormalUser = true;
      hashedPasswordFile = config.age.secrets.joaov-pw-hash.path;
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

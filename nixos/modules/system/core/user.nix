{
  self,
  inputs,
  ...
}: {
  flake.modules.nixos.user = {
    config,
    pkgs,
    lib,
    ...
  }: {
    users.mutableUsers = false;

    users.users.root.hashedPassword = "$y$j9T$Bl5EmI6hWVsFAMJ3CTMK1/$wLwMLfvak8ytE5SLvgMELaF6YEeNvjJs//5whbgFzb6";
    users.users.joaov = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$Bl5EmI6hWVsFAMJ3CTMK1/$wLwMLfvak8ytE5SLvgMELaF6YEeNvjJs//5whbgFzb6";
      extraGroups = ["wheel" "networkmanager" "render" "input" "adm" "audio" "video" "dialout" "plugdev" "i2c" "fuse" "gpio" "spi" "netdev" "games" "cdrom"];
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
        python3
      ];
    };
    assertions = [
      {
        assertion = !config.users.mutableUsers;
        message = "users must be immutable";
      }
    ];
  };
}

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

    users.users.root.hashedPassword = "$y$j9T$wlXYjqg/QqlcSvrY9yByV/$72cAizf8yT0Pw6NPLvt/kaQ8BpXQoZ0VEVAA/fXCsU5";
    users.users.joaov = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$wlXYjqg/QqlcSvrY9yByV/$72cAizf8yT0Pw6NPLvt/kaQ8BpXQoZ0VEVAA/fXCsU5";
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
    assertions = [
      {
        assertion = !config.users.mutableUsers;
        message = "users must be immutable";
      }
    ];
  };
}

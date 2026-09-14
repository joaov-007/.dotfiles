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


    users.users.root.hashedPassword = "$y$j9T$GWSRZO7Ei.3cF4vc3pA1A/$cl8hJ8hbSO6ATanQYmqYxtfF5kilmQj/l3Ax/48Cot/";
    users.users.joaov = {
      isNormalUser = true;
      hashedPassword = "$y$j9T$JGNdjh2bclSh3Hxhle814.$cYDwdbVp./b.n3.OavtJYF./7IUjyRXSVW1howLANo.";
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

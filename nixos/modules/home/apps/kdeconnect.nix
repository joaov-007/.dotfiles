{...}: {
  flake.nixosModules.kdeconnect = {...}: {
    networking.firewall = rec {
      allowedTCPPortRanges = [
        {
          from = 1714;
          to = 1764;
        }
      ];
      allowedUDPPortRanges = allowedTCPPortRanges;
    };
  };

  flake.homeModules.kdeconnect = {...}: {
    services.kdeconnect.enable = true;
  };
}

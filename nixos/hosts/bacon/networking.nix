{
  config,
  pkgs,
  ...
}: {
  networking.hostName = "bacon";
  networking.networkmanager.enable = true;

  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [22000];
  networking.firewall.allowedUDPPorts = [
    22000
    21027
  ];

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";
}

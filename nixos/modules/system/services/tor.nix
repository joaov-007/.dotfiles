{
  pkgs,
  config,
  lib,
  ...
}: let
  cfg = config.dev.system.services.tor;
in {
  options = {
    dev.system.services.tor.enable = lib.mkEnableOption "Enable tor service";
  };

  config = lib.mkIf cfg.enable {
    services.tor = {
      enable = true;
      openFirewall = true;

      enableGeoIP = true;

      # Enable Torsocks for transparent proxying of applications through Tor
      torsocks.enable = true;

      # Enable the Tor client
      client.enable = true;

      # Enable and configure the Tor relay
      relay = {
        enable = true;
        role = "relay"; # Set the relay role (e.g., "relay", "bridge")
      };

      # Configure Tor settings
      settings = {
        # Bandwidth settings
        MaxAdvertisedBandwidth = "100 MB";
        BandWidthRate = "50 MB";
        RelayBandwidthRate = "50 MB";
        RelayBandwidthBurst = "100 MB";

        # Restrict exit nodes to a specific country (use the appropriate country code)
        ExitNodes = "{us} StrictNodes 1";

        # Reject all exit traffic
        ExitPolicy = ["reject *:*"];

        # Performance and security settings
        CookieAuthentication = true;
        AvoidDiskWrites = 1;
        HardwareAccel = 1;
        SafeLogging = 1;
        NumCPUs = 2;

        # Network settings
        ORPort = [443 80];
      };
    };
  };
}

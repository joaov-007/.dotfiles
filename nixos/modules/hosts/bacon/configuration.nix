{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.bacon = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {inherit self inputs;};
    modules = with self.nixosModules; [
      bacon
      baconHardware
      preservation
      overlays
      intelDrivers
      desktop
      dev
      homeManager
      nixIndexDatabase
      doas
    ];
  };
  flake.nixosModules.bacon = {
    pkgs,
    lib,
    config,
    ...
  }: {
    networking.hostName = "bacon"; # Define your hostname.
    networking.networkmanager.enable = true;

    # Enable touchpad support (enabled default in most desktopManager).
    services.libinput.enable = true;

    # udisks2 backend for udiskie automount (configured in home-manager).
    services.udisks2.enable = true;

    # List packages installed in system profile.
    # You can use https://search.nixos.org/ to find more packages (and options).
    environment.systemPackages = with pkgs; [
    ];

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    programs.mtr.enable = true;
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    # Enable the OpenSSH daemon.
    services.openssh.enable = lib.mkForce false;

    networking.firewall.allowedTCPPorts = [];
    networking.firewall.allowedUDPPorts = [];

    system.copySystemConfiguration = lib.mkForce false;
<<<<<<< Updated upstream
||||||| Stash base

    networking.nameservers = [
      "1.1.1.1"
      "9.9.9.9"
      "8.8.8.8"
    ];

    services.resolved = {
      enable = true;
      settings.Resolve = {
        DNSSEC = "true";
        Domains = ["~."];
        DNSOverTLS = "true";
        FallbackDNS = [
          "1.1.1.1"
          "9.9.9.9"
          "8.8.8.8"
        ];
      };
    };
=======

    assertions = [
      {
        assertion = !config.services.openssh.enable;
        message = "openssh must be disabled on bacon";
      }
      {
        assertion = config.system.copySystemConfiguration == false;
        message = "copySystemConfiguration must be disabled";
      }
      {
        assertion = config.networking.firewall.enable;
        message = "firewall must be enabled";
      }
    ];
>>>>>>> Stashed changes
  };
}

{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.securityBase = {
    pkgs,
    lib,
    config,
    ...
  }: let
    apparmorProfiles = {
    };
  in {
    # --- Audit ---
    security = {
      auditd.enable = true;
      audit.enable = true;
    };

    # --- Firewall visibility ---
    networking.firewall = {
      logReversePathDrops = true; # log martian packets
      logRefusedConnections = true;
    };

    # --- /proc hardening (hidepid) ---
    #  boot.specialFileSystems."/proc" = {
    #    fsType = "proc";
    #    options = ["hidepid=2" "gid=wheel"];
    #  };

    # --- Login banner (BANN-7126) ---
    environment.etc."issue".text = ''
      Authorized access only. All activity is monitored and logged.
    '';

    # --- Memory allocator hardening ---
    environment.memoryAllocator.provider = "scudo";
    environment.variables.SCUDO_OPTIONS = "zero_contents=true";

    # --- AppArmor ---
    security.apparmor = {
      enable = true;
      # ponytail: killUnconfinedConfinables kills systemd-hibernate and other
      # unconfined system services. Disable until all critical services have
      # AppArmor profiles.
      killUnconfinedConfinables = false;
      policies = apparmorProfiles;
    };

    assertions = [
      {
        assertion = config.security.auditd.enable;
        message = "auditd must be enabled for security logging";
      }
      {
        assertion = config.security.audit.enable;
        message = "audit must be enabled for syscall logging";
      }
      {
        assertion = config.security.apparmor.enable;
        message = "AppArmor must be enabled";
      }
      {
        assertion = config.networking.firewall.logReversePathDrops;
        message = "firewall must log reverse path drops";
      }
      {
        assertion = config.networking.firewall.logRefusedConnections;
        message = "firewall must log refused connections";
      }
      {
        assertion = config.environment.memoryAllocator.provider == "scudo";
        message = "memory allocator must be scudo";
      }
      {
        assertion = config.environment.variables.SCUDO_OPTIONS == "zero_contents=true";
        message = "SCUDO_OPTIONS must zero contents";
      }
    ];

    #  Escape hatch: boot without AppArmor if something breaks
    # specialisation.no-apparmor.configuration = {
    #   security.apparmor.enable = lib.mkForce false;
    # };
  };
}

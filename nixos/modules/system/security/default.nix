{
  self,
  inputs,
  ...
}: {
  flake.modules.nixos.securityBase = {
    pkgs,
    lib,
    config,
    ...
  }: {
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

    environment.etc."issue".text = ''
      Authorized access only. All activity is monitored and logged.
    '';

    # --- Memory allocator hardening ---
    # environment.memoryAllocator.provider = "scudo";
    # environment.variables.SCUDO_OPTIONS = "zero_contents=true";

    # --- AppArmor ---
    security.apparmor = {
      enable = true;
      killUnconfinedConfinables = false;
      # policies = apparmorProfiles;
    };

    #  Escape hatch: boot without AppArmor if something breaks
    # specialisation.no-apparmor.configuration = {
    #   security.apparmor.enable = lib.mkForce false;
    # };
  };
}

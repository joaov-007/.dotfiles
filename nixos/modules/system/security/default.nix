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
      curl = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/curl";};
      dig = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/dig";};
      "bin.ping" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/bin.ping";};
      free = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/free";};
      hostname = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/hostname";};
      lsblk = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsblk";};
      lsof = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsof";};
      lsusb = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsusb";};
      tar = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tar";};
      nautilus = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nautilus";};
      podman = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/podman";};
    };
  in {
    # --- Audit ---
    security = {
      auditd.enable = true;
      audit.enable = true;
    };

    # --- AppArmor ---
    security.apparmor = {
      enable = true;
      # ponytail: killUnconfinedConfinables kills systemd-hibernate and other
      # unconfined system services. Disable until all critical services have
      # AppArmor profiles.
      killUnconfinedConfinables = false;
      policies = apparmorProfiles;
    };

    #  Escape hatch: boot without AppArmor if something breaks
    # specialisation.no-apparmor.configuration = {
    #   security.apparmor.enable = lib.mkForce false;
    # };
  };
}

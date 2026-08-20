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
    # Ponytail: upstream profiles use FHS paths (/usr/bin/*) but NixOS aliases
    # them to /run/current-system/sw/bin via includes.nix. Start with complain,
    # move to enforce after verifying with aa-status + journalctl.
    apparmorProfiles = {
      # --- Network utilities ---
      curl = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/curl";
      };
      dig = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/dig";
      };
      "bin.ping" = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/bin.ping";
      };

      # --- System utilities ---
      free = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/free";
      };
      hostname = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/hostname";
      };
      lsblk = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsblk";
      };
      lsof = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsof";
      };
      lsusb = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsusb";
      };
      tar = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tar";
      };

      # --- Desktop ---
      nautilus = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nautilus";
      };

      # --- Container runtime ---
      podman = {
        state = "complain";
        path = "${pkgs.apparmor-profiles}/etc/apparmor.d/podman";
      };
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
      policies = apparmorProfiles;
    };

    #  Escape hatch: boot without AppArmor if something breaks
    # specialisation.no-apparmor.configuration = {
    #   security.apparmor.enable = lib.mkForce false;
    # };
  };
}

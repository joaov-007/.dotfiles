{...}: {
  flake.modules.nixos.securityTools = {pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      lynis # security auditing tool (CIS/Hardening checks)
      unhide # forensic tool to find hidden processes/ports
      # rkhunter and chkrootkit are not available in nixpkgs at this time
      # (chkrootkit removed as unmaintained; rkhunter eval not available).
    ];
  };
}

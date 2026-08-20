{inputs, ...}: {
  flake.nixosModules.preservation = {...}: {
    imports = [
      inputs.preservation.nixosModules.default
    ];
    config = {
      programs.fuse.userAllowOther = true;
      preservation = {
        enable = true;
        preserveAt."/.persistent" = {
          directories = [
            "/etc/nixos"
            "/var/log"
            "/var/lib/nixos"
            "/var/lib/systemd"
            "/var/lib/bluetooth"
            "/var/lib/NetworkManager"
            "/etc/NetworkManager/system-connections/"
            "/etc/ssh"
            "/var/lib/colord"
            "/var/log/aide/"
            "/var/lib/aide/"
            "/var/lib/audit"
          ];
          files = [
            {
              file = "/etc/machine-id";
              inInitrd = true;
            }
          ];
        };
      };
    };
  };
}

{
  inputs,
  ...
}: {
  imports = [
    inputs.preservation.nixosModules.default
  ];

  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

  preservation = {
    enable = true;
    preserveAt."/persistent" = {
      files = [
        {
          file = "/etc/machine-id";
          inInitrd = true;
        }
      ];
        directories = [
          "/etc/nixos"
          "/var/lib/nixos"
          "/var/log"
          "/var/lib/bluetooth/"
          "/var/lib/NetworkManager"
          "/root/.ssh"
          "/etc/ssh"
          "/var/lib/colord"
          "/var/lib/ollama"
          "/var/lib/systemd"
          "/var/lib/gdm"
          "/var/lib/AccountsService"
        ];
    };
  };
}

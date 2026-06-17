{
  pkgs,
  config,
  lib,
  inputs,
  modulesPath,
  ...
}: {
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  networking.hostName = "loki";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Sao_Paulo";

  environment.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  environment.systemPackages = with pkgs; [
    inputs.nixos-anywhere.packages.${pkgs.system}.default
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    useXkbConfig = true;
  };

  nixpkgs.overlays = [inputs.neovim-nightly.overlays.default];

  # sd-image-aarch64 sets generic-extlinux-compatible; override shared _nixos systemd-boot
  boot.loader.systemd-boot.enable = lib.mkForce false;

  users.users.root.hashedPasswordFile = config.sops.secrets."root-password".path;

  users.users.jaov = {
    isNormalUser = true;
    extraGroups = ["wheel" "adm" "networkmanager" "podman"];
    hashedPasswordFile = config.sops.secrets."jaov-password".path;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKchsvMA7J9ZFDtmb0kj+h5w0H2bkCQi0suw8tNyWEG0 jaov@loki"
    ];
  };

  services.openssh = {
    enable = true;
    hostKeys = [
      {
        path = "/etc/ssh/ssh_host_ed25519_key";
        type = "ed25519";
      }
      {
        path = "/etc/ssh/ssh_host_rsa_key";
        type = "rsa";
        bits = 4096;
      }
    ];
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  dev.user = {
    name = "jaov";
    email = "9527341+joaov-007@users.noreply.github.com";
  };

  system.stateVersion = "25.11";
}

{
  config,
  lib,
  pkgs,
  inputs,
  ...
}: {
  time.timeZone = "America/Sao_Paulo";

  services.btrfs.autoScrub.enable = true;
  boot.initrd.availableKernelModules = ["btrfs"];

  environment.variables.NIX_REMOTE = "daemon";

  systemd.services.nix-daemon = {
    environment = {
      # Location for temporary files
      TMPDIR = "/var/cache/nix";
    };
    serviceConfig = {
      # Create /var/cache/nix automatically on Nix Daemon start
      CacheDirectory = "nix";
    };
  };

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "pt_BR.UTF-8/UTF-8"
    "en_US.UTF-8/UTF-8"
  ];

  services.xserver.xkb = {
    layout = "us";
    variant = "intl-unicode";
  };

  environment.persistence."/persist" = {
    # Hide these mount from the sidebar of file managers
    hideMounts = true;

    # Folders you want to map
    directories = [
      "/etc/NetworkManager/system-connections"
      "/root"
      "/var"
    ];

    # Files you want to map
    files = [
      "/etc/machine-id"
      "/etc/ssh/ssh_host_ed25519_key.pub"
      "/etc/ssh/ssh_host_ed25519_key"
      "/etc/ssh/ssh_host_rsa_key.pub"
      "/etc/ssh/ssh_host_rsa_key"
    ];

    # Similarly, you can map files and folders in users' home directories
    users.joaov = {
      directories = [
      ];
      files = [];
    };
  };

  console = {
    useXkbConfig = true; # use xkb.options in tty.
  };

  environment.gnome.excludePackages = with pkgs; [
    gnome-tour
    epiphany
  ];

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  nixpkgs.config.allowUnfree = true;

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    bluetooth.enable = true;
  };

  services = {
    displayManager.gdm.enable = true;
    displayManager.gdm.wayland = true;
    desktopManager.gnome.enable = true;

    gnome.games.enable = false;

    libinput.enable = true;

    ollama = {
      enable = true;
      package = pkgs.ollama-cpu;
    };

    pipewire = {
      enable = true;
      wireplumber.enable = true;
      pulse.enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      jack.enable = true;
    };

    geoclue2 = {
      enable = false;
    };

    fstrim = {
      enable = true;
    };
  };

  #TODO: I think can make better the user.user

  dev = {
    boot.plymouth.enable = false;
    boot.systemd-boot.enable = true;
    system.updates.enable = true;

    user.users = {
      joaov = {
        description = "Joao Victor";
        admin = true;
        shell = pkgs.zsh;
      };
    };
  };

  # programs.firefox.enable = true;

  programs.zsh.enable = true;
  programs.nix-index-database.comma.enable = true;

  services.blueman.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
    xclip
    librewolf
    alejandra
    git
    bitwarden-desktop
    bitwarden-cli
    jq
    calibre
    rclone
    borgbackup
    pika-backup
    age
    sops
    otpclient
    e2fsprogs
    trash-cli
    # android-tools
    # scrcpy
    # qtscrcpy
  ];

  security = {
    polkit.enable = true;
    auditd.enable = true;
    rtkit.enable = true;
  };

  # specialisation.no-apparmor.configuration = {
  #  security.apparmor.enable = lib.mkForce false;
  # };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  services.openssh.enable = lib.mkForce false;
}

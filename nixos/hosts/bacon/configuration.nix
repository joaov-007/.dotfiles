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
      # preservation is opt-in only (modules/system/settings/preservation.nix):
      # bacon keeps state on explicit btrfs subvolumes, not preservation.
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
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];

    networking.hostName = "bacon";

    networking.networkmanager.enable = true;

    services.libinput.enable = true;

    services.udisks2.enable = true;

    environment.systemPackages = with pkgs; [
      git
      btop
      file
      github-cli
    ];

    # Some programs need SUID wrappers, can be configured further or are
    # started in user sessions.
    programs.mtr.enable = true;
    programs.gnupg.agent = {
      enable = true;
      enableSSHSupport = true;
    };

    nixpkgs.overlays = [
      inputs.nur.overlays.default
      # inputs.chaotic.overlays.default
      inputs.neovim-nightly.overlays.default
    ];

    # Enable the OpenSSH daemon.
    services.openssh.enable = lib.mkForce false;

    services.openssh.package = pkgs.openssh;

    networking.firewall.allowedTCPPorts = [];
    networking.firewall.allowedUDPPorts = [];

    system.copySystemConfiguration = lib.mkForce false;

    home-manager = {
      useGlobalPkgs = true;
      backupFileExtension = "backup";
      extraSpecialArgs = {inherit self inputs;};
      sharedModules = [
        self.homeModules.default
      ];
      users.joaov = self.homeModules.joaov;
    };
  };
}

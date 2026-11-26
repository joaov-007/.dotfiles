{
  inputs,
  self,
  ...
}: {
  flake.nixosConfigurations.bacon = inputs.nixpkgs.lib.nixosSystem {
    specialArgs = {inherit self inputs;};
    modules = with self.nixosModules; [
      bacon

      intelDrivers
      desktop
      # dev
      # home
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
      ./_hardware-configuration.nix
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
      foot
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
      inputs.neovim-nightly.overlays.default
    ];

    services.openssh.enable = lib.mkForce false;
    services.openssh.package = pkgs.openssh;

    networking.firewall.allowedTCPPorts = [];
    networking.firewall.allowedUDPPorts = [];

    system.copySystemConfiguration = lib.mkForce false;
  };
}

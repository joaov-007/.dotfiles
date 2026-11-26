{
  inputs,
  self,
  ...
}: {
  flake.modules.nixos.bacon = {
    pkgs,
    lib,
    config,
    ...
  }: {
    imports = [
      ./_hardware-configuration.nix
      inputs.self.modules.nixos.nix
      inputs.self.modules.nixos.intelDrivers
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

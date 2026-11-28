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
    ];

    networking.hostName = "bacon";

    networking.networkmanager.enable = true;

    services.libinput.enable = true;

    services.udisks2.enable = true;

    environment.systemPackages = with pkgs; [
      file
      self.packages.${pkgs.stdenv.hostPlatform.system}.openbot
      xvfb # needed by the openbot background user service
    ];

    # User-level OpenBot service: starts in background without opening the UI.
    # Runs under a virtual X display (xvfb) so no window appears on the desktop.
    # Conflicts with the desktop autostart/session instance using the same
    # ~/.config/OpenBot profile - disable one before enabling the other.
    systemd.user.services.openbot = {
      description = "OpenBot (background, no UI)";
      documentation = ["https://openbot.run/"];
      after = ["network.target"];
      wants = ["network.target"];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.xvfb}/bin/xvfb-run -a ${lib.getExe self.packages.${pkgs.stdenv.hostPlatform.system}.openbot}";
        Restart = "on-failure";
        RestartSec = 5;
        # Virtual X display, not the user's Wayland session.
        Environment = [
          "NIXOS_OZONE_WL="
        ];
      };
      wantedBy = ["default.target"];
    };

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

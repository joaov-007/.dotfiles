{self, ...}: {
  perSystem = {
    pkgs,
    lib,
    self',
    ...
  }: let
    system = pkgs.stdenv.hostPlatform.system;
    bacon = self.nixosConfigurations.bacon.config;
    home = bacon.home-manager.users.joaov;
    niriSettings = self.niriSettings {
      inherit pkgs;
      noctalia = self'.packages.noctalia;
    };
    terminalBinding = niriSettings.binds."Mod+Return" {};
    jetBrainsMono = "JetBrainsMono Nerd Font";

    nwgLookInstalled =
      builtins.any (
        package: (package.pname or "") == "nwg-look"
      )
      bacon.environment.systemPackages;
    configuration = assert lib.asserts.assertMsg bacon.stylix.enable
    "Stylix must be enabled in the Bacon configuration";
    assert lib.asserts.assertMsg
    (bacon.stylix.cursor.name == "Bibata-Modern-Ice" && bacon.stylix.cursor.size == 20)
    "The Bibata-Modern-Ice cursor must be configured at size 20";
    assert lib.asserts.assertMsg
    (builtins.all (name: name == jetBrainsMono) [
      bacon.stylix.fonts.serif.name
      bacon.stylix.fonts.sansSerif.name
      bacon.stylix.fonts.monospace.name
    ])
    "JetBrainsMono Nerd Font must be used for every text font family";
    assert lib.asserts.assertMsg nwgLookInstalled
    "nwg-look must be installed in the Bacon system profile";
    assert lib.asserts.assertMsg (home.gtk.iconTheme.name == "Papirus-Dark")
    "The dark Papirus icon theme must be applied to Joaov's GTK configuration";
    assert lib.asserts.assertMsg (home.home.file.".config/nvim".source != null)
    "Joaov's editable Neovim configuration must be linked by Home Manager";
    assert lib.asserts.assertMsg self.yaziSettings.yazi.mgr.show_hidden
    "The shared Yazi settings must be present";
    assert lib.asserts.assertMsg (niriSettings.layout.gaps == 8)
    "The shared Niri settings must be present";
    assert lib.asserts.assertMsg
    (terminalBinding.content.spawn == [(lib.getExe pkgs.alacritty)])
    "Mod+Return must launch the package-provided Alacritty executable";
      pkgs.writeText "configuration-check" ''
        Bacon NixOS evaluation: OK
        Joaov Home Manager evaluation: OK
        Stylix fonts and cursor: OK
        Desktop icons and nwg-look: OK
        Editable Neovim configuration: OK
        Shared Niri and Yazi settings: OK
      '';
  in {
    # Building the NixOS closure also evaluates every imported NixOS and Home
    # Manager module. Package checks automatically cover newly added wrappers.
    checks =
      self'.packages
      // lib.optionalAttrs (system == "x86_64-linux") {
        inherit configuration;
        nixos-bacon = bacon.system.build.toplevel;
        home-manager-joaov = home.home.activationPackage;
      };
  };
}

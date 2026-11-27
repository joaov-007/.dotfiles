{self, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    bacon = self.nixosConfigurations.bacon.config;
    home = bacon.home-manager.users.joaov;
    colors = bacon.lib.stylix.colors;
  in {
    # Pure config assertions: no NixOS closure build, so they can run on any
    # system supported by the pinned nixpkgs (x86_64-darwin was dropped in 26.11).
    checks = lib.optionalAttrs (system != "x86_64-darwin") {
      stylix = assert lib.asserts.assertMsg bacon.stylix.enable
      "Stylix must be enabled in the Bacon configuration";
      assert lib.asserts.assertMsg
      (bacon.stylix.cursor.name == "Bibata-Modern-Ice" && bacon.stylix.cursor.size == 20)
      "The Bibata-Modern-Ice cursor must be configured at size 20";
      assert lib.asserts.assertMsg
      (bacon.stylix.fonts.serif.name == "Inter" && bacon.stylix.fonts.sansSerif.name == "Inter")
      "Inter must be used for interface and document text";
      assert lib.asserts.assertMsg
      (bacon.stylix.fonts.monospace.name == "JetBrainsMono Nerd Font")
      "JetBrainsMono Nerd Font must remain the monospace font";
      assert lib.asserts.assertMsg (colors.base08 == "f7768e")
      "Base08 must use Tokyo Night red for errors";
      assert lib.asserts.assertMsg (colors.base03 == "6b7396" && colors.base04 == "8a8fae")
      "Outline and secondary text must use the accessible palette overrides";
      assert lib.asserts.assertMsg
      (home.stylix.targets.gtk.enable && home.stylix.targets.noctalia.enable && home.stylix.targets.qt.enable)
      "Stylix must explicitly cover GTK, Noctalia, and Qt";
      assert lib.asserts.assertMsg
      (home.gtk.theme.name == "adw-gtk3-dark" && home.gtk.gtk4.theme.name == "adw-gtk3-dark")
      "GTK3 and GTK4 must both use the dark theme";
      assert lib.asserts.assertMsg (home.qt.platformTheme.name == "qtct")
      "Qt must keep using the Stylix qtct integration";
      assert lib.asserts.assertMsg
      (home.programs.noctalia.settings.shell.font_family == "Inter")
      "Noctalia must inherit the Inter interface font from Stylix";
      assert lib.asserts.assertMsg
      (home.programs.noctalia.settings.theme.mode == "dark")
      "Noctalia must follow the fixed dark Stylix polarity";
      assert lib.asserts.assertMsg (bacon.stylix.image != null)
      "Stylix must provide the default Noctalia wallpaper";
        pkgs.runCommand "stylix-check" {} "touch $out";
    };
  };
}

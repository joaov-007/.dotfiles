{
  self,
  self',
  ...
}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    niriSettings = self.niriSettings {
      inherit pkgs;
      colors = self.desktopPalette;
      noctalia = self'.packages.noctalia;
    };
    terminalBinding = niriSettings.binds."Mod+Return" {};
    launcherAlias = niriSettings.binds."Mod+D" {};
    sessionBinding = niriSettings.binds."Mod+Shift+Q" {};
    visibleTitles = lib.filter (title: title != null) (map (
      bind: let
        evaluated = bind {};
      in
        evaluated.props."hotkey-overlay-title" or null
    ) (lib.attrValues niriSettings.binds));
  in {
    # Pure config assertions: no NixOS closure build, so they can run on any
    # system supported by the pinned nixpkgs (x86_64-darwin was dropped in 26.11).
    checks = lib.optionalAttrs (system != "x86_64-darwin") {
      niri-settings = assert lib.asserts.assertMsg (niriSettings.layout.gaps == 8)
      "The shared Niri settings must be present";
      assert lib.asserts.assertMsg
      (terminalBinding.content.spawn == [(lib.getExe pkgs.alacritty)])
      "Mod+Return must launch the package-provided Alacritty executable";
      assert lib.asserts.assertMsg
      (niriSettings.layout.focus-ring.active-color == "#${self.desktopPalette.base0D}")
      "Niri focus rings must use the shared accent color";
      assert lib.asserts.assertMsg
      (niriSettings.layout.border.inactive-color == "#${self.desktopPalette.base03}")
      "Niri inactive borders must use the shared outline color";
      assert lib.asserts.assertMsg
      (builtins.length visibleTitles == builtins.length (lib.unique visibleTitles))
      "Visible Niri hotkey overlay titles must be unique";
      assert lib.asserts.assertMsg
      (launcherAlias.props."hotkey-overlay-title" == null)
      "Alias bindings must stay out of the hotkey overlay";
      assert lib.asserts.assertMsg
      (sessionBinding.content."spawn-sh" == "noctalia msg panel-toggle session")
      "Mod+Shift+Q must open the session menu instead of quitting Niri";
      assert lib.asserts.assertMsg (lib.hasInfix "passes 1" niriSettings.extraConfig)
      "Niri blur must use the single-pass performance budget";
        pkgs.runCommand "niri-settings-check" {} "touch $out";
    };
  };
}

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
      noctalia = self'.packages.noctalia;
    };
    terminalBinding = niriSettings.binds."Mod+Return" {};
  in {
    # Pure config assertions: no NixOS closure build, so they can run on any
    # system supported by the pinned nixpkgs (x86_64-darwin was dropped in 26.11).
    checks = lib.optionalAttrs (system != "x86_64-darwin") {
      niri-settings = assert lib.asserts.assertMsg (niriSettings.layout.gaps == 8)
      "The shared Niri settings must be present";
      assert lib.asserts.assertMsg
      (terminalBinding.content.spawn == [(lib.getExe pkgs.alacritty)])
      "Mod+Return must launch the package-provided Alacritty executable";
        pkgs.runCommand "niri-settings-check" {} "touch $out";
    };
  };
}

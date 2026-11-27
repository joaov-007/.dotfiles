{self, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    bacon = self.nixosConfigurations.bacon.config;
    jetBrainsMono = "JetBrainsMono Nerd Font";
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
      (builtins.all (name: name == jetBrainsMono) [
        bacon.stylix.fonts.serif.name
        bacon.stylix.fonts.sansSerif.name
        bacon.stylix.fonts.monospace.name
      ])
      "JetBrainsMono Nerd Font must be used for every text font family";
        pkgs.runCommand "stylix-check" {} "touch $out";
    };
  };
}

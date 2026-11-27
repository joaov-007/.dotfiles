{self, ...}: {
  perSystem = {
    pkgs,
    system,
    lib,
    ...
  }: let
    bacon = self.nixosConfigurations.bacon.config;
    home = bacon.home-manager.users.joaov;
    installed = name:
      builtins.any (p: (p.pname or "") == name) bacon.environment.systemPackages;
  in {
    # Pure config assertions: no NixOS closure build, so they can run on any
    # system supported by the pinned nixpkgs (x86_64-darwin was dropped in 26.11).
    checks = lib.optionalAttrs (system != "x86_64-darwin") {
      desktop = assert lib.asserts.assertMsg (installed "nwg-look")
      "nwg-look must be installed in the Bacon system profile";
      assert lib.asserts.assertMsg (installed "wl-clipboard")
      "wl-clipboard must be installed for Wayland clipboard support";
      assert lib.asserts.assertMsg (installed "xclip")
      "xclip must be installed as an X11 clipboard fallback";
      assert lib.asserts.assertMsg (home.gtk.iconTheme.name == "Papirus-Dark")
      "The dark Papirus icon theme must be applied to Joaov's GTK configuration";
      assert lib.asserts.assertMsg bacon.programs.seahorse.enable
      "Seahorse must be enabled in the Bacon configuration";
      assert lib.asserts.assertMsg
      (home.programs.noctalia.settings.shell.launch_apps_as_systemd_services == self.noctaliaSettings.shell.launch_apps_as_systemd_services)
      "Noctalia must inherit the shared application launch setting";
      assert lib.asserts.assertMsg
      (home.programs.noctalia.settings.theme.templates.community_ids == self.noctaliaSettings.theme.templates.community_ids)
      "Noctalia must inherit the shared template settings";
        pkgs.runCommand "desktop-check" {} "touch $out";
    };
  };
}

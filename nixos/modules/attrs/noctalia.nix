{
  inputs,
  self,
  ...
}: {
  flake.noctaliaSettings = {
    shell.niri_overview_type_to_launch_enabled = true;
    shell.launch_apps_as_systemd_services = true;
    theme.templates = {
      enable_builtin_templates = true;
      enable_community_templates = true;
      community_ids = ["obsidian"];
    };
  };

  perSystem = {
    system,
    pkgs,
    ...
  }: {
    packages.noctalia =
      (inputs.wrappers-modules.lib.wrapModule {
        imports = [inputs.wrappers-modules.wrapperModules.noctalia-shell];
        inherit pkgs;
        package = inputs.noctalia.packages.${system}.default;
        settings = self.noctaliaSettings;
      }).wrapper;
  };
}

{
  inputs,
  ...
}: {
  flake.homeModules.noctalia = {pkgs, ...}: {
    imports = [
      inputs.noctalia.homeModules.default
    ];

    programs.noctalia = {
      enable = true;
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
      settings = {
        shell.niri_overview_type_to_launch_enabled = true;
        shell.launch_apps_as_systemd_services = true;
        theme.templates = {
          enable_builtin_templates = true;
          enable_community_templates = true;
          community_ids = ["obsidian"];
        };
      };
    };
  };
}

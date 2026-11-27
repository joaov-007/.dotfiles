{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.developmentTools = moduleWithSystem ({pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      devenv
    ];
  });

  flake.modules.homeManager.developmentTools = moduleWithSystem ({...}: {
    imports = with self.modules.homeManager; [
      git
      nvim
      pi
    ];

    programs.lazygit = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.devenv = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.herdr.enable = true;
  });
}

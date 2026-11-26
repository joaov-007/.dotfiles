{
  self,
  moduleWithSystem,
  ...
}: {
  flake.modules.nixos.developmentTools = moduleWithSystem ({pkgs, ...}: {
    environment.systemPackages = with pkgs; [
      opencode
      devenv
    ];
  });

  flake.modules.homeManager.developmentTools = moduleWithSystem ({pkgs, ...}: {
    imports = with self.modules.homeManager; [
      git
      pi
    ];

    programs.lazygit = {
      enable = true;
      enableBashIntegration = true;
      settings.gui.nerdFontsVersion = "3";
    };
    programs.devenv = {
      enable = true;
      enableBashIntegration = true;
    };
    programs.herdr.enable = true;

    programs.neovim = {
      enable = true;
      plugins = [
        {
          plugin = pkgs.vimPlugins.nvim-web-devicons;
          type = "lua";
          config = ''require("nvim-web-devicons").setup {}'';
        }
      ];
    };
  });
}

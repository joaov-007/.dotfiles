{
  inputs,
  moduleWithSystem,
  ...
}: {
  perSystem = moduleWithSystem (
    {
      pkgs,
      self',
      ...
    }: {
      packages.noctalia =
        (inputs.wrappers-modules.lib.wrapModule {
          imports = [inputs.wrappers-modules.wrapperModules.noctalia-shell];
          inherit pkgs;
          package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default;
          settings =
            inputs.self.noctaliaSettings
            // {
              plugins = {
                sources = [
                  {
                    enabled = true;
                    name = "official";
                    url = "https://github.com/noctalia-dev/official-plugins";
                  }
                  {
                    enabled = true;
                    name = "community";
                    url = "https://github.com/noctalia-dev/community-plugins";
                  }
                ];
                states = {
                  screen_recorder.enabled = true;
                  translator.enabled = true;
                  timer.enabled = true;
                  wallhaven.enabled = true;
                  world_clock.enabled = true;
                  github-activity.enabled = true;
                  git-companion.enabled = true;
                };
                version = 2;
              };
            };
        }).wrapper;

      packages.niri = inputs.wrappers-modules.wrappers.niri.wrap {
        inherit pkgs;
        settings = inputs.self.niriSettings {
          inherit pkgs;
          colors = inputs.self.desktopPalette;
          noctalia = self'.packages.noctalia;
        };
      };
    }
  );
}

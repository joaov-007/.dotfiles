{
  inputs,
  self,
  ...
}: {
  flake.yaziSettings = {
    yazi = {
      mgr = {
        show_hidden = true;
        sort_by = "natural";
        sort_dir_first = true;
        linemode = "size";
        mouse_support = true;
      };
      opener = {
        edit = [
          {
            run = ''nvim "$@"'';
            desc = "Edit with nvim";
            block = true;
          }
        ];
      };
      open = {
        rules = [
          {
            name = "*/";
            use = ["edit"];
          }
          {
            mime = "text/*";
            use = ["edit"];
          }
        ];
      };
    };
    keymap = {};
  };

  perSystem = {
    system,
    pkgs,
    ...
  }: {
    packages.yazi =
      (inputs.wrappers-modules.lib.wrapModule {
        imports = [inputs.wrappers-modules.wrapperModules.yazi];
        inherit pkgs;
        package = pkgs.yazi;
        settings = self.yaziSettings;
      }).wrapper;
  };
}

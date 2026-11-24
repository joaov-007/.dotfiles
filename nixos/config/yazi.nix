{
  inputs,
  self,
  ...
}: {
  flake.modules.yaziSettings = {
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
}

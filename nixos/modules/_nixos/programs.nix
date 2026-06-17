{ config, lib, ... }:

let
  cfg = config.programsBundles;
in {
  options.programsBundles = {
    enable = lib.mkEnableOption "program bundles activation";

    bundles = lib.mkOption {
      type = lib.types.listOf (lib.types.submodule {
        options = {
          name = lib.mkOption {
            type = lib.types.str;
            description = "Program name matching programs.<name>";
          };
          enable = lib.mkEnableOption "this program";
          extraConfig = lib.mkOption {
            type = lib.types.attrsOf lib.types.raw;
            default = {};
            description = "Extra configuration for the program";
          };
        };
      });
      default = [];
      description = "List of programs to activate via programs.<name>.enable";
      example = [
        {
          name = "git";
          enable = true;
          extraConfig = {
            extraConfig = {
              user.name = "foo";
            };
          };
        }
        { name = "firefox"; enable = true; }
      ];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge (map (p: lib.mkIf p.enable {
      programs.${p.name} = {
        enable = true;
      } // p.extraConfig;
    }) cfg.bundles)
  );
}

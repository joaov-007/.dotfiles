
{...}: {
  flake.modules.home.dotfiles = {
    config,
    lib,
    symlinkRoot,
    ...
  }: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    root = "${symlinkRoot}/config/shared";

    entries = builtins.readDir root;

    links = lib.mapAttrs' (name: _: {
      name = name;
      value = {
        source = mkOutOfStoreSymlink "${root}/${name}";
        recursive = true;
      };
    }) entries;
  in {
    home.file = links;
  };
}

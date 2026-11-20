{input, ...}: {
  flake.homeModules.dotfiles = {
    config,
    lib,
    symlinkRoot,
    ...
  }: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    link = name:
      mkOutOfStoreSymlink "${symlinkRoot}/${name}";

    files = [
    ];

    dirs = [
    ];

    fileEntries = lib.genAttrs files (name: {
      source = link name;
    });

    dirEntries = lib.genAttrs dirs (name: {
      source = link name;
      recursive = true;
    });
  in {
    xdg.configFile = fileEntries // dirEntries;
  };
}

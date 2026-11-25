{input, ...}: {
  flake.homeModules.dotfiles = {
    config,
    lib,
    symlinkRoot,
    ...
  }: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    root = "${symlinkRoot}/config/shared";

    folders = [
      ".config"
      ".local"
    ];

    link = path:
      mkOutOfStoreSymlink "${root}/${path}";

    discover = folder: let
      contents = builtins.readDir "${root}/${folder}";
    in
      lib.mapAttrs' (
        name: type:
          lib.nameValuePair "${folder}/${name}" {
            source = link "${folder}/${name}";
          }
      ) (
        lib.filterAttrs (_: type: type == "directory") contents
      );
  in {
    home.file = lib.foldl' (
      acc: folder:
        acc // discover folder
    ) {}
    folders;
  };
}

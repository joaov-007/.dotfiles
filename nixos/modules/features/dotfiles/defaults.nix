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

    files = [
    ];

    recursive = true;

    # Create an out-of-store symlink.
    link = path:
      mkOutOfStoreSymlink "${root}/${path}";

    # Discover directory contents.
    discover = source: destination: let
      contents = builtins.readDir "${root}/${source}";
      names = builtins.attrNames contents;
    in
      lib.foldl' (
        acc: name: let
          type = contents.${name};
          src = "${source}/${name}";
          dst = "${destination}/${name}";
        in
          if type == "directory" && recursive
          then acc // discover src dst
          else
            acc
            // {
              ${dst} = {
                source = link src;
              };
            }
      ) {}
      names;

    # Map configured folders.
    folderEntries =
      lib.foldl' (
        acc: folder:
          acc // discover folder folder
      ) {}
      folders;

    # Map explicitly configured files.
    fileEntries = lib.genAttrs files (name: {
      source = link name;
    });
  in {
    home.file = folderEntries // fileEntries;
  };
}

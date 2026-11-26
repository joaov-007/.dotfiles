{...}: {
  flake.modules.homeManager.dotfiles = {
    config,
    lib,
    symlinkRoot,
    ...
  }: let
    inherit (config.lib.file) mkOutOfStoreSymlink;

    root = "${symlinkRoot}/config/shared";

    # Pi mixes portable files with Nix-generated settings and themes, so its
    # module links the individual files instead of linking the whole directory.
    entries = builtins.removeAttrs (builtins.readDir root) [".pi"];

    links =
      lib.mapAttrs' (name: _: {
        name = name;
        value = {
          source = mkOutOfStoreSymlink "${root}/${name}";
          recursive = true;
        };
      })
      entries;
  in {
    home.file = links;
  };
}

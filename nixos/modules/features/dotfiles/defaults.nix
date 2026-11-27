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
    topLevel = builtins.removeAttrs (builtins.readDir root) [".pi"];

    # Neovim is linked as an editable directory by its own module, so exclude
    # it from the recursive .config link to avoid overlapping Home Manager paths.
    configDir = "${root}/.config";
    configEntries =
      lib.filterAttrs (name: _: name != "nvim") (builtins.readDir configDir);

    configLinks =
      lib.mapAttrs' (name: _: {
        name = ".config/${name}";
        value = {
          source = mkOutOfStoreSymlink "${configDir}/${name}";
          recursive = true;
        };
      })
      configEntries;

    topLevelLinks =
      lib.mapAttrs' (name: _: {
        name = name;
        value = {
          source = mkOutOfStoreSymlink "${root}/${name}";
          recursive = true;
        };
      })
      (lib.filterAttrs (name: _: name != ".config") topLevel);
  in {
    home.file = topLevelLinks // configLinks;
  };
}

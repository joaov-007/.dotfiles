{lib, ...}: let
  inherit (builtins) filter baseNameOf;
  root = toString ./.;
  nixFiles = lib.filesystem.listFilesRecursive ./.;
  moduleFiles =
    filter
    (f: lib.hasSuffix ".nix" f && baseNameOf f != "default.nix")
    nixFiles;
  stripRoot = f: lib.removePrefix root (toString f);
in {
  imports = map (f: "${root}/${f}") (map stripRoot moduleFiles);
}

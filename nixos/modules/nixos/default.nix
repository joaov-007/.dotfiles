{ lib, ... }: let
  inherit (builtins) filter baseNameOf;
  nixFiles = lib.filesystem.listFilesRecursive ./.;
  moduleFiles = filter
    (f: lib.hasSuffix ".nix" f && baseNameOf f != "default.nix")
    nixFiles;
in {
  imports = moduleFiles;
}

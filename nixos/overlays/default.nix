{lib}: let
  files = lib.pipe ./. [
    builtins.readDir
    (lib.filterAttrs (n: t: t == "regular" && n != "default.nix" && lib.hasSuffix ".nix" n))
    builtins.attrNames
  ];
in
  lib.genAttrs files (file: import (./. + "/${file}"))

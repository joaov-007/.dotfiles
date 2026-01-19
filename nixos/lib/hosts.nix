{lib}:
lib.pipe ../hosts [
  builtins.readDir
  (lib.filterAttrs (_: type: type == "directory"))
  builtins.attrNames
]

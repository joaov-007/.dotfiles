{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.dev.home.git;
in {
  options.dev.home.git = {};
  config = {};
}

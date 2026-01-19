{
  inputs,
  system,
}: let
  nixpkgs = inputs.nixpkgs;
  lib = nixpkgs.lib;
in {
  inherit lib;

  pkgs = import ./pkgs.nix {inherit inputs system;};
  hosts = import ./hosts.nix {inherit lib;};
  mkHost = import ./mk-host.nix {inherit inputs system;};
}

{...}: {
  flake.nixosModules.nix-ld = {pkgs, ...}: {
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        util-linux
        stdenv.cc.cc
        zlib
        libusb1
      ];
    };
  };
}

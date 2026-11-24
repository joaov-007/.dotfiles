{moduleWithSystem, ...}: {
  flake.nixosModules.nix-ld = moduleWithSystem ({pkgs, ...}: {
    programs = {
      nix-ld = {
        enable = true;
        libraries = with pkgs; [
          util-linux
          stdenv.cc.cc
          zlib
          libusb1
        ];
      };
    };
  });
}

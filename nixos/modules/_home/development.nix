{pkgs, ...}: let
  gcc-alias = pkgs.runCommand "gcc" {} ''
    mkdir -p $out/bin
    ln -s ${pkgs.clang}/bin/clang $out/bin/gcc
    ln -s ${pkgs.clang}/bin/clang++ $out/bin/g++
  '';
in {
  home.packages = with pkgs; [
    gcc-alias
    nodejs
    rustup
    go
    clang
    clang-tools
    llvm
    gdb
    cmake
    gnumake
    pkg-config
    openssl
  ];
}

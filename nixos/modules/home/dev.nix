{pkgs, ...}: {
  home.packages = with pkgs; [
    clang
    zig

    # Rust toolchain manager
    rustup

    # Build tools
    gnumake
    cmake
    pkg-config
  ];
}

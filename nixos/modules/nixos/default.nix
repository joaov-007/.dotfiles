{
  imports = [
    ./sops.nix
    ./systemd-boot.nix
    ./preservation.nix
    ./nix.nix
    ./networking.nix
    ./auto-update.nix
    ./ollama.nix
  ];
}

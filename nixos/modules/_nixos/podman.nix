{
  pkgs,
  config,
  lib,
  ...
}: {
  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
    defaultNetwork.settings.dns_enabled = true;
  };

  virtualisation.containers.registries.search = ["docker.io" "ghcr.io"];

  environment.systemPackages = with pkgs; [podman-compose];
}

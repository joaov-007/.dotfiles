{...}: {
  flake.nixosModules.podman = {
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

    virtualisation.containers.registries.settings = {
      unqualified-search-registries = ["docker.io" "ghcr.io" "quay.io"];
    };

    environment.systemPackages = with pkgs; [podman-compose];
  };
}

{self, ...}: {
  flake.modules.nixos.tor = {pkgs, ...}: {
    imports = [self.modules.nixos.podman];

    # Tor SOCKS proxy in an isolated Podman container (no host network).
    # Exposes only a local SOCKS5 endpoint for apps explicitly configured to use it.
    virtualisation.oci-containers.containers.tor-socks-proxy = {
      image = "docker.io/peterdavehello/tor-socks-proxy@sha256:0cc12d36d31265ce828c8422a7e163a0bf46755e90531f4c7d38a6149f071729";
      ports = ["127.0.0.1:9050:9150/tcp"];
      extraOptions = [
        "--cap-drop=ALL"
        "--security-opt=no-new-privileges:true"
      ];
    };

    environment.systemPackages = with pkgs; [
      tor-browser
      torsocks
    ];
  };
}

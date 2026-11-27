{self, ...}: {
  flake.modules.nixos.litellm = {
    lib,
    pkgs,
    ...
  }: let
    configFile = pkgs.writeText "litellm-config.yaml" ''
      model_list:
        - model_name: local-general
          litellm_params:
            model: ollama/qwen2.5:1.5b
            api_base: http://127.0.0.1:11434
        - model_name: local-code
          litellm_params:
            model: ollama/qwen2.5-coder:1.5b
            api_base: http://127.0.0.1:11434

      general_settings:
        master_key: os.environ/LITELLM_MASTER_KEY

      litellm_settings:
        drop_params: true
    '';
  in {
    imports = [self.modules.nixos.podman];

    services.ollama = {
      enable = true;
      host = "127.0.0.1";
      port = 11434;
      loadModels = [
        "qwen2.5:1.5b"
        "qwen2.5-coder:1.5b"
      ];
      environmentVariables = {
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NUM_PARALLEL = "1";
      };
    };

    virtualisation.oci-containers = {
      backend = "podman";
      containers.litellm = {
        image = "ghcr.io/berriai/litellm:main-v1.82.3";
        cmd = [
          "--config"
          "/etc/litellm/config.yaml"
          "--host"
          "127.0.0.1"
          "--port"
          "4000"
        ];
        volumes = ["${configFile}:/etc/litellm/config.yaml:ro"];
        environmentFiles = ["/etc/litellm.env"];
        extraOptions = ["--network=host"];
      };
    };

    systemd.services.podman-litellm = {
      after = ["ollama.service"];
      requires = ["ollama.service"];
      preStart = lib.mkBefore ''
        if [ ! -s /etc/litellm.env ]; then
          ${pkgs.coreutils}/bin/printf 'LITELLM_MASTER_KEY=sk-%s\n' \
            "$(${pkgs.openssl}/bin/openssl rand -hex 32)" \
            > /etc/litellm.env
        fi
        ${pkgs.coreutils}/bin/chmod 0600 /etc/litellm.env
      '';
    };

    systemd.tmpfiles.rules = [
      "f /etc/litellm.env 0600 root root -"
    ];
  };
}

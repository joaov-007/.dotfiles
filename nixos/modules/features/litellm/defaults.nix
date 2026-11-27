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
        - model_name: cloud-groq
          litellm_params:
            model: groq/openai/gpt-oss-20b
            api_key: os.environ/GROQ_API_KEY
        - model_name: cloud-openrouter
          litellm_params:
            model: openrouter/liquid/lfm-3-1.7b:free
            api_key: os.environ/OPENROUTER_API_KEY
        - model_name: cloud-groq-big
          litellm_params:
            model: groq/openai/gpt-oss-120b
            api_key: os.environ/GROQ_API_KEY
        - model_name: cloud-mistral
          litellm_params:
            model: mistral/mistral-small-latest
            api_key: os.environ/MISTRAL_API_KEY
        - model_name: cloud-mistral-mini
          litellm_params:
            model: mistral/ministral-8b-latest
            api_key: os.environ/MISTRAL_API_KEY
        - model_name: cloud-code
          litellm_params:
            model: mistral/codestral-latest
            api_key: os.environ/MISTRAL_API_KEY
        - model_name: cloud-nemotron
          litellm_params:
            model: openrouter/nvidia/nemotron-3.5-lightning:free
            api_key: os.environ/OPENROUTER_API_KEY
        - model_name: cloud-gemma
          litellm_params:
            model: openrouter/google/gemma-4-31b-it:free
            api_key: os.environ/OPENROUTER_API_KEY
        - model_name: cloud-free
          litellm_params:
            model: openrouter/openrouter/free
            api_key: os.environ/OPENROUTER_API_KEY

      general_settings:
        master_key: os.environ/LITELLM_MASTER_KEY

      litellm_settings:
        drop_params: true
        num_retries: 2
        request_timeout: 120
        fallbacks:
          - cloud-groq: ["cloud-mistral", "cloud-free", "local-general"]
          - cloud-groq-big: ["cloud-groq", "cloud-free", "local-general"]
          - cloud-mistral: ["cloud-groq", "cloud-free", "local-general"]
          - cloud-mistral-mini: ["cloud-mistral", "cloud-free", "local-general"]
          - cloud-code: ["local-code"]
          - cloud-openrouter: ["cloud-free", "local-general"]
          - cloud-nemotron: ["cloud-gemma", "cloud-free", "local-general"]
          - cloud-gemma: ["cloud-nemotron", "cloud-free", "local-general"]
          - cloud-free: ["cloud-groq", "local-general"]
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

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
        - model_name: local-medium
          litellm_params:
            model: ollama/qwen3:8b
            api_base: http://127.0.0.1:11434
            num_ctx: 8192
        - model_name: local-uncensored
          litellm_params:
            model: ollama/hf.co/mradermacher/Qwen2.5-3B-Instruct-abliterated-GGUF:Q4_K_M
            api_base: http://127.0.0.1:11434
            num_ctx: 8192
        - model_name: local-dolphin
          litellm_params:
            model: ollama/hf.co/bartowski/Dolphin3.0-Llama3.2-3B-GGUF:Q4_K_M
            api_base: http://127.0.0.1:11434
            num_ctx: 8192
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
          - local-medium: ["local-general"]
          - local-uncensored: ["local-dolphin", "local-medium", "local-general"]
          - local-dolphin: ["local-uncensored", "local-medium", "local-general"]
          - cloud-groq: ["cloud-mistral", "cloud-free", "local-medium", "local-general"]
          - cloud-groq-big: ["cloud-groq", "cloud-free", "local-medium", "local-general"]
          - cloud-mistral: ["cloud-groq", "cloud-free", "local-medium", "local-general"]
          - cloud-mistral-mini: ["cloud-mistral", "cloud-free", "local-medium", "local-general"]
          - cloud-code: ["local-code", "local-medium"]
          - cloud-openrouter: ["cloud-free", "local-medium", "local-general"]
          - cloud-nemotron: ["cloud-gemma", "cloud-free", "local-medium", "local-general"]
          - cloud-gemma: ["cloud-nemotron", "cloud-free", "local-medium", "local-general"]
          - cloud-free: ["cloud-groq", "local-medium", "local-general"]
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
        "qwen3:8b"
        "hf.co/mradermacher/Qwen2.5-3B-Instruct-abliterated-GGUF:Q4_K_M"
        "hf.co/bartowski/Dolphin3.0-Llama3.2-3B-GGUF:Q4_K_M"
      ];
      environmentVariables = {
        OLLAMA_MAX_LOADED_MODELS = "1";
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_KEEP_ALIVE = "5m";
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
      # Secrets live in /etc/litellm.env (root-owned, mode 0600, not in the Nix
      # store). This preStart only ensures the file exists, has a master key, and
      # declares the expected cloud key names; it never overwrites existing values.
      preStart = lib.mkBefore ''
        env=/etc/litellm.env
        if [ ! -e "$env" ]; then
          ${pkgs.coreutils}/bin/touch "$env"
        fi
        ${pkgs.coreutils}/bin/chmod 0600 "$env"
        if ! ${pkgs.gnugrep}/bin/grep -q '^LITELLM_MASTER_KEY=' "$env"; then
          ${pkgs.coreutils}/bin/printf 'LITELLM_MASTER_KEY=sk-%s\n' \
            "$(${pkgs.openssl}/bin/openssl rand -hex 32)" >> "$env"
        fi
        for k in GROQ_API_KEY OPENROUTER_API_KEY MISTRAL_API_KEY; do
          if ! ${pkgs.gnugrep}/bin/grep -q "^''${k}=" "$env"; then
            ${pkgs.coreutils}/bin/printf '%s=\n' "$k" >> "$env"
          fi
        done
      '';
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "litellm-health-check" ''
        set -euo pipefail

        ollama_ok=0
        litellm_ok=0

        if ${pkgs.curl}/bin/curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null; then
          ollama_ok=1
          echo "ollama: ok"
        else
          echo "ollama: fail"
        fi

        litellm_code="$(${pkgs.curl}/bin/curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:4000/health/readiness || true)"
        if [ "$litellm_code" = "200" ]; then
          litellm_ok=1
          echo "litellm: ok"
        else
          echo "litellm: fail (http $litellm_code)"
        fi

        if [ "$ollama_ok" -eq 1 ] && [ "$litellm_ok" -eq 1 ]; then
          exit 0
        fi
        exit 1
      '')
    ];

    systemd.services.litellm-health-check = {
      description = "Health check for Ollama and LiteLLM";
      after = ["ollama.service" "podman-litellm.service"];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "litellm-health-check-exec" ''
          set -euo pipefail
          ${pkgs.curl}/bin/curl -fsS --max-time 5 http://127.0.0.1:11434/api/tags >/dev/null
          code="$(${pkgs.curl}/bin/curl -sS -o /dev/null -w '%{http_code}' --max-time 5 http://127.0.0.1:4000/health/readiness || true)"
          [ "$code" = "200" ]
        ''}";
      };
    };

    systemd.timers.litellm-health-check = {
      description = "Periodic health check for Ollama and LiteLLM";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = "5min";
        Unit = "litellm-health-check.service";
      };
    };

    systemd.tmpfiles.rules = [
      "f /etc/litellm.env 0600 root root -"
    ];
  };
}

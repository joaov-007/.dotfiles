{...}: {
  flake.nixosModules.ollama = {
    lib,
    pkgs,
    config,
    ...
  }: {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-cpu;

      loadModels = [
        "qwen2.5-coder:1.5b"
      ];

      environmentVariables = {
        OLLAMA_CONTEXT_LENGTH = "8192";
        OLLAMA_KEEP_ALIVE = "5m";
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_LOADED_MODELS = "1";
      };
    };

    zramSwap = {
      enable = true;
      memoryPercent = 50;
      algorithm = "zstd";
    };
  };
}

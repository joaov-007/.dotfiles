{...}: {
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    openFirewall = false;
    environment = {
      OLLAMA_BASE_URL = "http://127.0.0.1:11434";
      ANONYMIZED_TELEMETRY = "False";
      DO_NOT_TRACK = "True";
      SCARF_NO_ANALYTICS = "True";
    };
  };
}

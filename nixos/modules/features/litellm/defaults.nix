{...}: {
  flake.modules.nixos.litellm = {...}: {
    services.litellm = {
      enable = true;
      host = "127.0.0.1";
      port = 4000;

      # Keep provider credentials and LITELLM_MASTER_KEY out of the Nix store.
      # The empty file is created on activation; edit it with root permissions.
      environmentFile = "/etc/litellm.env";
      environment = {
        # Peer authentication works with the service's dynamic "litellm" user.
        DATABASE_URL = "postgresql://litellm@localhost/litellm?host=/run/postgresql";
      };
      settings.general_settings.store_model_in_db = true;
    };

    services.postgresql = {
      enable = true;
      ensureDatabases = ["litellm"];
      ensureUsers = [
        {
          name = "litellm";
          ensureDBOwnership = true;
        }
      ];
    };

    systemd.services.litellm = {
      # Wait for postgresql-setup to create the database and role.
      after = ["postgresql.target"];
      requires = ["postgresql.target"];
    };

    systemd.tmpfiles.rules = [
      "f /etc/litellm.env 0600 root root -"
    ];
  };
}

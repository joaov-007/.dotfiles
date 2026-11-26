{...}: {
  flake.modules.homeManager.udiskie = {...}: {
    services.udiskie = {
      enable = true;
      automount = true;
      notify = true;
      tray = "never";
    };
  };
}

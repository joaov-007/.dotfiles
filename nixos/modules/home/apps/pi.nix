{...}: {
  flake.homeModules.pi = {
    pkgs,
    ...
  }: {
    programs.pi-coding-agent.enable = true;
  };
}

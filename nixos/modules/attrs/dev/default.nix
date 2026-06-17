{self, ...}: {
  flake.homeModules.dev = let
    modules = with self.homeModules; [
      git
      nvim
      shell
    ];
  in {
    imports = modules;
  };
}

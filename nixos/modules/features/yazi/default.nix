{inputs, ...}: {
  perSystem = {
    system,
    pkgs,
    ...
  }: {
    packages.yazi =
      (inputs.wrappers-modules.lib.wrapModule {
        imports = [inputs.wrappers-modules.wrapperModules.yazi];
        inherit pkgs;
        package = pkgs.yazi;
        settings = inputs.self.yaziSettings;
      }).wrapper;
  };
}

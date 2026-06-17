{inputs, ...}: {
  flake.homeModules.joaov = {lib, ...}: {
    home = {
      username = "joaov";
      homeDirectory = "/home/joaov";
    };
  };
}

{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.doas = {
    pkgs,
    lib,
    ...
  }: {
    # doas: lighter sudo replacement (OpenBSD-born, ~1k LOC vs sudo's ~100k)
    security.doas = {
      enable = true;
      wheelNeedsPassword = false;
    };

    # Kill sudo entirely — nothing in this config should need it
    security.sudo.enable = false;

    environment.systemPackages = [pkgs.doas]; # ensure doas is on PATH
  };
}

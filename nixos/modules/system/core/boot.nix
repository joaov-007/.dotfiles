{inputs, ...}: {
  flake.nixosModules.boot = {
    config,
    pkgs,
    ...
  }: {
    config = {
      boot = {
        kernelPackages = pkgs.linuxPackages_cachyos;
        loader = {
          timeout = 3;
          systemd-boot.enable = true;
          efi.canTouchEfiVariables = true;
          systemd-boot.configurationLimit = 32;
        };
        kernel.sysctl = {
          "vm.swappiness" = 50;
        };
        plymouth = {
          enable = true;
          theme = "bgrt";
          themePackages = with pkgs; [];
        };
      };
      services.scx.enable = true;
    };
  };
}

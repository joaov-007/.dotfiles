{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.audio = {
    config,
    pkgs,
    lib,
    ...
  }: {
    config = {
      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        audio.enable = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        # jack.enable = true;
        wireplumber.enable = true;
      };

      environment.systemPackages = with pkgs; [
        playerctl
        pavucontrol
      ];
    };
  };
}

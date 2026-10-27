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
      assertions = [
        {
          assertion = !config.services.pulseaudio.enable;
          message = "pulseaudio must be disabled (pipewire replaces it)";
        }
        {
          assertion = config.services.pipewire.enable;
          message = "pipewire must be enabled";
        }
      ];

      environment.systemPackages = with pkgs; [
        playerctl
        pavucontrol
      ];

      services.pulseaudio.enable = false;
      security.rtkit.enable = true;
      services.pipewire = {
        enable = true;
        audio.enable = true;
        pulse.enable = true;
        alsa.enable = true;
        alsa.support32Bit = true;
        jack.enable = true;
        wireplumber.enable = true;
      };
    };
  };
}

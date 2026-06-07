{pkgs, ...}: {
  home.packages = with pkgs; [
    pass
    passExtensions.pass-otp
    passExtensions.pass-import
  ];
  services.gpg-agent.enableBashIntegration = true;
}

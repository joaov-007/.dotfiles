{pkgs, ...}: {
  flake.nixosModules.clamav = {...}: {
    # ClamAV — honest use case on a Linux desktop: scanning files you'll forward
    # to Windows machines, not real-time Linux protection (signatures are ~all
    # Windows malware). On-demand Downloads scan only; daemon is socket-activated
    # so it only runs while a scan is in progress.
    services.clamav = {
      daemon.enable = true;
      daemon.settings.MaxThreads = "4"; # cap so a scan doesn't steal all cores
      updater.enable = true;
      scanner.enable = true;
      scanner.scanDirectories = ["/home/joaov/Downloads"];
    };
  };
}

{...}: {
  flake.nixosModules.clamav = {pkgs,...}: {
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

    # Alert on detection: clamdscan exits non-zero when infected files are found
    # (no built-in NixOS alert option) — surface it as a desktop notification.
    systemd.services.clamav-notify = {
      serviceConfig = {
        Type = "oneshot";
        User = "joaov";
      };
      script = ''
        ${pkgs.libnotify}/bin/notify-send --urgency=critical "ClamAV: infected files found" "Check: journalctl -u clamdscan"
      '';
    };
    systemd.services.clamdscan.onFailure = ["clamav-notify.service"];
  };
}

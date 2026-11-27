{...}: {
  flake.modules.nixos.clamav = {pkgs, ...}: {
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
      fangfrisch.enable = true; # sanesecurity, urlhaus, securiteinfo
    };

    # Alert on detection: clamdscan exits non-zero when infected files are found
    # (no built-in NixOS alert option) — surface it as a desktop notification.
    systemd.services.clamav-notify = {
      description = "ClamAV desktop virus notification";
      serviceConfig = {
        Type = "oneshot";
        User = "joaov";
      };
      script = ''
        set -eu

        uid="$(${pkgs.coreutils}/bin/id -u joaov)"
        export DBUS_SESSION_BUS_ADDRESS="''${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$uid/bus}"
        export XDG_RUNTIME_DIR="''${XDG_RUNTIME_DIR:-/run/user/$uid}"

        findings="$(${pkgs.systemd}/bin/journalctl -u clamdscan --no-pager -n 80 2>/dev/null \
          | ${pkgs.gnugrep}/bin/grep -E "FOUND|INFECTED|Eicar" \
          | ${pkgs.coreutils}/bin/tail -n 6 || true)"

        if [ -z "$findings" ]; then
          findings="Nenhuma linha FOUND/INFECTED recente capturada. Verifique: journalctl -u clamdscan -n 80"
        fi

        summary="ClamAV: possível ameaça detectada"
        body="Arquivos possivelmente infectados foram encontrados durante o scan.

$findings

Ver detalhes: journalctl -u clamdscan --no-pager -n 80"

        ${pkgs.libnotify}/bin/notify-send \
          --urgency=critical \
          --icon=security-high \
          --app-name="ClamAV" \
          "$summary" \
          "$body" || true

        ${pkgs.util-linux}/bin/logger -t clamav-notify -- "ClamAV detection notification triggered; findings: $findings" || true
      '';
    };
    systemd.services.clamdscan.onFailure = ["clamav-notify.service"];
  };
}

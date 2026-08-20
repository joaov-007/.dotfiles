{pkgs, ...}: {
  flake.nixosModules.aide = {pkgs, ...}: {
    # AIDE (Advanced Intrusion Detection Environment) — file integrity monitoring.
    # No NixOS module exists upstream; package + own systemd timer (Discourse consensus).
    # Monitor the mutable attack surface only: /nix/store is content-addressed and
    # root-owned — nix-store --verify is the real check there, AIDE would be noise.
    environment.etc."aide.conf" = {
      mode = "0600";
      text = ''
        database_in = file:/var/lib/aide/aide.db
        database_out = file:/var/lib/aide/aide.db.new
        report_url = file:/var/log/aide/aide.log
        report_url = stdout

        # p=perms i=inode n=name u=uid g=gid s=size m=mtime c=ctime + sha512
        # no 'a' (atime): reading a file must not trigger alerts
        R = p+i+n+u+g+s+m+c+acl+xattrs+sha512
        # symlink rule: checks link target only — /etc is mostly store symlinks
        # regenerated on every rebuild, so content hashing it = daily alert noise
        L = p+i+n+u+g+acl+xattrs

        /etc            L
        /root           R
        /boot           R
        /var/lib/aide   R
        /home/joaov/.ssh    R
        /home/joaov/.gnupg  R

        # volatile / pointless on NixOS
        !/proc
        !/sys
        !/dev
        !/run
        !/tmp
        !/var/tmp
        !/var/log
        !/nix/store
        !/nix/var
        !/home/joaov/.cache
      '';
    };

    systemd.services.aide-check = {
      description = "AIDE integrity check";
      serviceConfig = {
        Type = "oneshot";
        # don't fight the desktop
        Nice = 10;
        IOSchedulingPriority = 7;
        StandardOutput = "journal";
        StandardError = "journal";
      };
      path = [pkgs.aide];
      script = ''
        set -u
        ${pkgs.aide}/bin/aide -c /etc/aide.conf --check
        rc=$?
        if [ $rc -ne 0 ]; then
          echo "AIDE: integrity check FAILED (rc=$rc) — changes detected"
        fi
        exit $rc
      '';
    };

    systemd.timers.aide-check = {
      description = "Daily AIDE integrity check";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnCalendar = "*-*-* 04:30:00";
        Persistent = true; # run after boot if the machine was off at 04:30
        RandomizedDelaySec = "15m";
        Unit = "aide-check.service";
      };
    };
  };
}
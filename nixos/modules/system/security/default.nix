{
  self,
  inputs,
  ...
}: {
  flake.nixosModules.securityBase = {
    pkgs,
    lib,
    config,
    ...
  }: let
    apparmorProfiles = {
      "1password" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/1password";};
      alsamixer = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/alsamixer";};
      "apache2.d" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/apache2.d";};
      babeld = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/babeld";};
      "balena-etcher" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/balena-etcher";};
      bfdd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/bfdd";};
      bgpd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/bgpd";};
      "bin.ping" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/bin.ping";};
      brave = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/brave";};
      buildah = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/buildah";};
      busybox = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/busybox";};
      cam = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/cam";};
      "ch-checkns" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ch-checkns";};
      chrome = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/chrome";};
      chromium = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/chromium";};
      "ch-run" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ch-run";};
      code = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/code";};
      crun = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/crun";};
      curl = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/curl";};
      devhelp = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/devhelp";};
      dig = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/dig";};
      Discord = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/Discord";};
      dnstracer = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/dnstracer";};
      eigrpd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/eigrpd";};
      "element-desktop" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/element-desktop";};
      epiphany = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/epiphany";};
      evolution = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/evolution";};
      fabricd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/fabricd";};
      firefox = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/firefox";};
      foliate = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/foliate";};
      free = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/free";};
      fusermount3 = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/fusermount3";};
      geary = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/geary";};
      "github-desktop" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/github-desktop";};
      "glycin.bwrap" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/glycin.bwrap";};
      "glycin.loaders" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/glycin.loaders";};
      goldendict = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/goldendict";};
      gs = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/gs";};
      hostname = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/hostname";};
      "iotop-c" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/iotop-c";};
      ipa_verify = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ipa_verify";};
      isisd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/isisd";};
      john = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/john";};
      kchmviewer = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/kchmviewer";};
      keybase = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/keybase";};
      "lc-compliance" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lc-compliance";};
      ldpd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ldpd";};
      libcamerify = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/libcamerify";};
      "linux-sandbox" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/linux-sandbox";};
      locale = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/locale";};
      loupe = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/loupe";};
      lsblk = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsblk";};
      lsb_release = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsb_release";};
      lsof = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsof";};
      lsusb = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lsusb";};
      "lxc-attach" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-attach";};
      "lxc-create" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-create";};
      "lxc-destroy" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-destroy";};
      "lxc-execute" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-execute";};
      "lxc-stop" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-stop";};
      "lxc-unshare" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-unshare";};
      "lxc-usernsexec" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/lxc-usernsexec";};
      mbsync = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/mbsync";};
      mmdebstrap = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/mmdebstrap";};
      MongoDB_Compass = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/MongoDB_Compass";};
      mosquitto = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/mosquitto";};
      msedge = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/msedge";};
      nautilus = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nautilus";};
      "nc.openbsd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nc.openbsd";};
      nhrpd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nhrpd";};
      notepadqq = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/notepadqq";};
      "notify-send" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/notify-send";};
      nslookup = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nslookup";};
      nvidia_modprobe = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/nvidia_modprobe";};
      obsidian = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/obsidian";};
      opam = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/opam";};
      opera = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/opera";};
      ospf6d = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ospf6d";};
      ospfd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ospfd";};
      pageedit = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/pageedit";};
      pathd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/pathd";};
      pbrd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/pbrd";};
      "php-fpm" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/php-fpm";};
      pim6d = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/pim6d";};
      pimd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/pimd";};
      plasmashell = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/plasmashell";};
      podman = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/podman";};
      polypane = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/polypane";};
      privacybrowser = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/privacybrowser";};
      proftpd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/proftpd";};
      qcam = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/qcam";};
      qmapshack = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/qmapshack";};
      qpdf = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/qpdf";};
      QtWebEngineProcess = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/QtWebEngineProcess";};
      qutebrowser = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/qutebrowser";};
      ripd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ripd";};
      ripngd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ripngd";};
      rootlesskit = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/rootlesskit";};
      rpm = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/rpm";};
      rssguard = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/rssguard";};
      runc = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/runc";};
      rygel = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/rygel";};
      "samba-bgqd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/samba-bgqd";};
      "samba-dcerpcd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/samba-dcerpcd";};
      "samba-rpcd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/samba-rpcd";};
      "samba-rpcd-classic" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/samba-rpcd-classic";};
      "samba-rpcd-spoolss" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/samba-rpcd-spoolss";};
      "sbin.klogd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbin.klogd";};
      "sbin.syslogd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbin.syslogd";};
      "sbin.syslog-ng" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbin.syslog-ng";};
      sbuild = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild";};
      "sbuild-abort" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-abort";};
      "sbuild-adduser" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-adduser";};
      "sbuild-apt" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-apt";};
      "sbuild-checkpackages" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-checkpackages";};
      "sbuild-clean" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-clean";};
      "sbuild-createchroot" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-createchroot";};
      "sbuild-destroychroot" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-destroychroot";};
      "sbuild-distupgrade" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-distupgrade";};
      "sbuild-hold" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-hold";};
      "sbuild-shell" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-shell";};
      "sbuild-unhold" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-unhold";};
      "sbuild-update" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-update";};
      "sbuild-upgrade" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/sbuild-upgrade";};
      scide = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/scide";};
      "signal-desktop" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/signal-desktop";};
      slack = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/slack";};
      slirp4netns = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/slirp4netns";};
      "ssh-keyscan" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/ssh-keyscan";};
      staticd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/staticd";};
      steam = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/steam";};
      "stress-ng" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/stress-ng";};
      surfshark = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/surfshark";};
      "systemd-coredump" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/systemd-coredump";};
      "systemd-detect-virt" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/systemd-detect-virt";};
      tar = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tar";};
      thunderbird = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/thunderbird";};
      tinyproxy = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tinyproxy";};
      tnftp = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tnftp";};
      transmission = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/transmission";};
      trinity = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/trinity";};
      tshark = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tshark";};
      tup = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tup";};
      "tuxedo-control-center" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/tuxedo-control-center";};
      "unix-chkpwd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/unix-chkpwd";};
      unprivileged_userns = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/unprivileged_userns";};
      userbindmount = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/userbindmount";};
      "usr.bin.hwctl" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.bin.hwctl";};
      "usr.lib.apache2.mpm-prefork.apache2" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.apache2.mpm-prefork.apache2";};
      "usr.lib.dovecot.anvil" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.anvil";};
      "usr.lib.dovecot.auth" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.auth";};
      "usr.lib.dovecot.config" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.config";};
      "usr.lib.dovecot.deliver" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.deliver";};
      "usr.lib.dovecot.dict" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.dict";};
      "usr.lib.dovecot.director" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.director";};
      "usr.lib.dovecot.doveadm-server" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.doveadm-server";};
      "usr.lib.dovecot.dovecot-auth" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.dovecot-auth";};
      "usr.lib.dovecot.dovecot-lda" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.dovecot-lda";};
      "usr.lib.dovecot.imap" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.imap";};
      "usr.lib.dovecot.imap-login" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.imap-login";};
      "usr.lib.dovecot.lmtp" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.lmtp";};
      "usr.lib.dovecot.log" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.log";};
      "usr.lib.dovecot.managesieve" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.managesieve";};
      "usr.lib.dovecot.managesieve-login" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.managesieve-login";};
      "usr.lib.dovecot.pop3" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.pop3";};
      "usr.lib.dovecot.pop3-login" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.pop3-login";};
      "usr.lib.dovecot.replicator" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.replicator";};
      "usr.lib.dovecot.script-login" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.script-login";};
      "usr.lib.dovecot.ssl-params" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.ssl-params";};
      "usr.lib.dovecot.stats" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.lib.dovecot.stats";};
      "usr.sbin.apache2" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.apache2";};
      "usr.sbin.avahi-daemon" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.avahi-daemon";};
      "usr.sbin.dnsmasq" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.dnsmasq";};
      "usr.sbin.dovecot" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.dovecot";};
      "usr.sbin.identd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.identd";};
      "usr.sbin.mdnsd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.mdnsd";};
      "usr.sbin.nmbd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.nmbd";};
      "usr.sbin.nscd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.nscd";};
      "usr.sbin.ntpd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.ntpd";};
      "usr.sbin.smbd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.smbd";};
      "usr.sbin.smbldap-useradd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.smbldap-useradd";};
      "usr.sbin.traceroute" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.traceroute";};
      "usr.sbin.winbindd" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/usr.sbin.winbindd";};
      "uwsgi-core" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/uwsgi-core";};
      vdens = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/vdens";};
      virtiofsd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/virtiofsd";};
      "vivaldi-bin" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/vivaldi-bin";};
      vpnns = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/vpnns";};
      vrrpd = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/vrrpd";};
      wg = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/wg";};
      "wg-quick" = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/wg-quick";};
      who = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/who";};
      wike = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/wike";};
      wpa_supplicant = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/wpa_supplicant";};
      wpcom = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/wpcom";};
      Xorg = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/Xorg";};
      zgrep = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/zgrep";};
      znc = {path = "${pkgs.apparmor-profiles}/etc/apparmor.d/znc";};
    };
  in {
    # --- Audit ---
    security = {
      auditd.enable = true;
      audit.enable = true;
    };

    # --- Firewall visibility ---
    networking.firewall = {
      logReversePathDrops = true; # log martian packets
      logRefusedConnections = true;
    };

    # --- /proc hardening (hidepid) ---
    boot.specialFileSystems."/proc" = {
      fsType = "proc";
      options = ["hidepid=2" "gid=wheel"];
    };

    # --- Login banner (BANN-7126) ---
    environment.etc."issue".text = ''
      Authorized access only. All activity is monitored and logged.
    '';

    # --- Memory allocator hardening ---
    environment.memoryAllocator.provider = "scudo";
    environment.variables.SCUDO_OPTIONS = "zero_contents=true";

    # --- AppArmor ---
    security.apparmor = {
      enable = true;
      # ponytail: killUnconfinedConfinables kills systemd-hibernate and other
      # unconfined system services. Disable until all critical services have
      # AppArmor profiles.
      killUnconfinedConfinables = false;
      policies = apparmorProfiles;
    };

    #  Escape hatch: boot without AppArmor if something breaks
    # specialisation.no-apparmor.configuration = {
    #   security.apparmor.enable = lib.mkForce false;
    # };
  };
}

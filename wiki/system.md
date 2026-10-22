# System configuration

`etc/` mirrors the system configuration. It is not a Stow package for
`$HOME` — it is a Stow package for `/etc`, and it needs root:

```sh
sudo stow -t /etc etc
```

`.stow-local-ignore` keeps `etc` out of the `$HOME` packages, so a plain
`stow` never touches the system configuration by accident.

## What it installs

```
etc/
├── clamav/
│   ├── clamav-milter.conf
│   ├── clamd.conf
│   └── freshclam.conf
├── unbound/
│   └── unbound.conf
├── geoclue.conf
├── geoclue/
│   └── .keep
└── backups/
    ├── geoclue.conf
    └── unbound.conf
```

Stowing it creates these links:

| Target | Source |
| --- | --- |
| `/etc/clamav` | `etc/clamav` |
| `/etc/unbound` | `etc/unbound` |
| `/etc/geoclue.conf` | `etc/geoclue.conf` |
| `/etc/geoclue` | `etc/geoclue` |
| `/etc/backups` | `etc/backups` |

The directories become symlinks, so the live configuration *is* the file
in the repository. An edit is live after a restart of the service — there
is no copy step.

`/etc/backups` is linked as well. It holds the previous versions of the
two configuration files, and linking it into `/etc` puts it where nothing
looks for it. It is harmless, but it is not what the name suggests.

## unbound

The recursive resolver. It answers on `127.0.0.1` and `::1` only.

### Hardening

| Setting | What it does |
| --- | --- |
| `hide-identity`, `hide-version` | Do not advertise the server |
| `qname-minimisation` | Send the minimum of the query name upstream |
| `aggressive-nsec` | Use the NSEC records of a signed zone to block |
| `harden-glue` | Only trust glue that is within the authority |
| `harden-dnssec-stripped` | A signed zone that arrives unsigned is BOGUS |
| `use-caps-for-id: no` | Randomise the query ID — it breaks DNSSEC |
| `private-address`, `private-domain` | Never forward local addresses and names |

`edns-buffer-size: 1232` keeps the DNS queries inside a single packet, so
a middlebox cannot fragment them and read the name out of the second
fragment.

### Caching

```
msg-cache-size: 128m
rrset-cache-size: 256m
```

That is generous for a machine with one user. The comment in the file
says as much.

### Upstream

Every upstream is reached over DNS-over-TLS:

```
forward-addr: 1.1.1.1@853#cloudflare-dns.com
forward-addr: 9.9.9.11@853#dns.quad9.net
forward-addr: 94.140.14.15@853#family.adguard-dns.com
forward-addr: 185.228.168.9@853#security-filter-dns.cleanbrowsing.org
...
```

The root zone is forwarded to `127.0.0.1@55` first — a local
dnscrypt-proxy. The encrypted resolver is asked before the plain one, so
the plain upstreams never see the name.

The `remote-control` section enables `unbound-control` on
`127.0.0.1:9999`, with a key and a certificate.

### The adblock lists

`scripts/unbound/executable_get_unbound_adblock.sh` fetches the block
lists, converts them into `local-zone` entries and writes them to
`/etc/unbound/unbound.conf.d/_unbound-adhosts.conf`.

It keeps a timestamped backup of the previous file before it installs a
new one, and it restarts the service at the end. The script needs
`perl`, `python3` with the `tld` module, and root.

## ClamAV

| File | What it configures |
| --- | --- |
| `clamd.conf` | The daemon, the local socket, and the on-access scan |
| `clamav-milter.conf` | The milter that hands the mail scanner its socket |
| `freshclam.conf` | The signature updater and the extra databases |

`clamd.conf` scans `/home` on access:

```
OnAccessIncludePath /home
OnAccessMaxThreads 20
MaxDirectoryRecursion 20
```

Every access to a file under `/home` goes through the scanner. The
`VirusEvent` hook runs `/opt/clamav-alert.sh`, which is outside the
repository — it is a local script the machine needs.

`freshclam.conf` adds the Securiteinfo signature databases on top of the
official ones. The URL carries a hash, so it is not a public link.

## geoclue

The location service. The file is close to the distribution default, with
the WiFi source pointed at `api.beacondb.net` and a list of applications
that are allowed to ask for the location without a prompt.

The `etc/geoclue/` directory holds a `.keep`, so the directory exists
after the stow and the distribution does not recreate it.

## systemd user units

`rclone-services/` holds one unit:

```
rclone-services/rclone@egdrive.service
```

It syncs `~/Documents` to a remote, one direction, with the remote name
as the instance:

```sh
systemctl --user start rclone@egdrive.service
systemctl --user enable rclone@egdrive.service
```

The remote is configured in `~/.config/rclone/rclone.conf`, which is not
in the repository — it holds the credentials.

### The layout is wrong

The unit is at the root of the package, so `stow -t ~ rclone-services`
creates `~/rclone@egdrive.service`. systemd looks for user units in
`~/.config/systemd/user/`, so the unit is never loaded.

The fix is one directory level:

```
rclone-services/.config/systemd/user/rclone@egdrive.service
```

Until that happens, the unit has to be installed by hand:

```sh
mkdir -p ~/.config/systemd/user
ln -s ~/dotfiles/rclone-services/rclone@egdrive.service \
      ~/.config/systemd/user/rclone@egdrive.service
systemctl --user daemon-reload
```

## The security posture

Taken together, the configuration in this repository:

- resolves DNS locally, over TLS, with DNSSEC enforced and no identity
  leaked;
- blocks the advertising and tracking lists at the resolver;
- scans every file access under the home directory;
- runs the mail scanner through a milter;
- keeps the shell history in Atuin, encrypted, synced between machines;
- keeps the signing key in `gpg`, with `PASSWORD_STORE_ENABLE_EXTENSIONS`
  on for the password store;
- rebase-based git history with `rerere`, so a conflict is resolved once
  and remembered.

On the NixOS side, `nixos/modules/system/security/` and the checks in
`nixos/modules/tests/` cover the same ground declaratively, with
`doas` instead of `sudo`, AppArmor, AIDE and a firewall.

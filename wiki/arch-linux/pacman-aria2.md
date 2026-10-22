---
title: "Pacman with aria2 — Faster Downloads via XferCommand"
aliases:
  - Pacman aria2
  - aria2 XferCommand
  - Pacman Download Speed
description: >-
  Using aria2 as pacman's XferCommand to split package downloads across multiple
  connections, with every tuning flag explained so the setup speeds things up
  instead of breaking --sync transactions. Covers the failure modes (stale .part
  files, mirror throttling, proxy bypass) and how to roll back.
tags:
  - arch-linux
  - linux
  - pacman
  - aria2
  - downloads
  - mirrors
type: reference
status: evergreen
created: 2026-10-11
updated: 2026-10-11
last_reviewed: 2026-10-11
review_after: 2027-04-11
language: en
audience: "Arch users stuck on slow mirrors or throttled single-connection downloads"
scope: >-
  pacman.conf XferCommand wiring aria2 into pacman on Arch Linux. Tuning knobs,
  breakage modes, rollback. Not a general aria2 tutorial.
platform:
  - arch-linux
keywords:
  - aria2
  - aria2c
  - XferCommand
  - ParallelDownloads
  - pacman.conf
  - mirrors
sources:
  - "[aria2 — ArchWiki (pacman XferCommand)](https://wiki.archlinux.org/title/Aria2#pacman_XferCommand)"
  - "[pacman — ArchWiki (Parallel downloads)](https://wiki.archlinux.org/title/Pacman#Parallel_downloads)"
  - "[pacman.conf(5) — Arch manual pages (XferCommand, ParallelDownloads, sandbox)](https://man.archlinux.org/man/pacman.conf.5.en)"
source_retrieved: 2026-10-11
related:
  - "[[Arch Pro Setup]]"
  - "[[Arch dnscrypt-proxy — Encrypted DNS, Ad-Blocking and systemd Hardening]]"
  - "[[Home]]"
cssclasses:
  - reference
---

# Pacman with aria2 — Faster Downloads via XferCommand

> [!summary] One-paragraph answer
> Add one `XferCommand` line to `/etc/pacman.conf` and aria2 downloads every
> package across several parallel connections instead of one. That wins mainly on
> single large files (kernel, browsers, toolchains) served by a throttled or
> congested mirror. Modern pacman (7.0+) already parallelises *across* packages
> with `ParallelDownloads`, so aria2 is an add-on, not a replacement. Use the
> Arch Wiki command verbatim: every flag in it (`--no-conf`, `--file-allocation=none`,
> `--allow-overwrite`, `--out %o`) exists precisely so pacman transactions do not break.

## Context

Open this note when:

- a `pacman -Syu` crawls because one or two big packages (e.g. `linux`,
  `linux-firmware`, a browser) take forever on a mirror that throttles
  single connections;
- you want to know why so many `XferCommand` tutorials exist and which flags
  are load-bearing;
- a pasted `XferCommand` made pacman fail with "invalid or corrupted package"
  and you need to understand why.

`XferCommand` replaces pacman's built-in downloader with an external program for
every remote file (packages **and** database files). `%u` is replaced by the
download URL; `%o` is replaced by the local filename **plus a `.part`
extension** — that suffix is what lets downloaders resume, and pacman renames
the file once signature verification succeeds.

## Details

### 1. Install aria2 and back up pacman.conf

```bash
sudo pacman -S aria2
sudo cp /etc/pacman.conf /etc/pacman.conf.bak
```

### 2. Add the XferCommand

In `/etc/pacman.conf`, inside the `[options]` section (the one that already
holds `ParallelDownloads`):

```
XferCommand = /usr/bin/aria2c --allow-overwrite=true --continue=true --file-allocation=none --log-level=error --max-tries=2 --max-connection-per-server=2 --max-file-not-found=5 --min-split-size=5M --no-conf --remote-time=true --summary-interval=60 --timeout=5 --dir=/ --out %o %u
```

This is the current Arch Wiki command. Do not reorder or drop flags until you
have read §3 — several of them protect pacman, not speed.

### 3. What each flag does (fine-tuning without breaking things)

| Flag | Job | Touch this when… |
|---|---|---|
| `--continue=true` | Resume partial `.part` files | Leave as-is. This is what makes interrupted `-Syu` recoverable. |
| `--allow-overwrite=true` | Restart a file when no resume control file exists | Never remove. Without it aria2 can refuse to write over existing files. |
| `--dir=/ --out %o` | Write to the exact path pacman expects (the `.part` file) | Never remove `%o`. This is the contract with pacman. |
| `--file-allocation=none` | No preallocation before download | Keep `none`. On btrfs with compression `falloc` can fail (ENOSPC) and preallocation fights pacman's own disk-space checks. |
| `--no-conf` | Ignore `~/.config/aria2/aria2.conf` | Keep! Your daily-driver aria2 config (proxy, `dir`, speed limits) silently leaks into pacman downloads otherwise and is a classic source of "it speeds up my other downloads but breaks pacman". |
| `--max-connection-per-server=2` | Connections per file per mirror | **The main speed knob.** Raise to 8–16 on a fast link. Mirrors throttle per IP: too high → 403/connection resets → "failed retrieving file". Tune up, then watch one big download. |
| `--min-split-size=5M` | Split only files ≥ 2× this (10 MB) | Lower to `1M` to split smaller packages; most packages are under 10 MB and never split at all. You get overhead on tiny files for nothing. |
| `--max-tries=2`, `--timeout=5` | Retry/timeout per connection | Lower `--timeout` further on a mirror that hangs instead of failing; don't raise it unless mirrors time out too quickly for you. |
| `--max-file-not-found=5` | Tolerate 404s (deltas, missing files) | Leave alone; prevents a single missing file killing the transaction. |
| `--summary-interval=60` | Progress spam cadence | Set `0` for quieter output. |
| `--remote-time=true` | Keep server mtime | Leave; keeps cache/`paccache` semantics sane. |

### 4. How it stacks with ParallelDownloads

`ParallelDownloads = N` (default on since pacman 7.0.0; shipped config uses 5)
downloads up to *N files at once*. The `XferCommand` splits *one* file across
`--max-connection-per-server` connections. Both can be active: N streams per
file × M files. That multiplier is why aggressive settings get you banned by
mirrors — if you raise `--max-connection-per-server`, keep `ParallelDownloads`
modest.

> [!info] Where the win actually is
> aria2's splitting does nothing for a transaction of 200 small packages — those
> are limited by TCP setup latency and are exactly what `ParallelDownloads`
> fixes. aria2 pays off on few, large downloads from a per-connection-throttled
> mirror. If downloads are slow everywhere, rank mirrors first (e.g.
> `reflector`), then tune `ParallelDownloads`, then add aria2 for the big files.

### 5. Alternative without touching the config

Want aria2 speed without an `XferCommand`? Download the URLs and let pacman go
to cache:

```bash
pacman -Sp <package> | aria2c -i -           # download to cwd
sudo pacman -U /path/to/<package>.pkg.tar.zst
```

Useful for `-Syu` of a specific heavy package from a laptop on bad Wi-Fi. The
wiki pipeline is `pacman -Sp` (prints URLs without downloading) piped into
`aria2c -i -` (read URIs from stdin), then install from file.

### 6. Rolling back

```bash
# comment out the XferCommand line, then:
sudo pacman -Syu
```

The built-in downloader returns (plain progress bar, single connection per
file, `ParallelDownloads` still honoured). Verify with §Verification.

## Gotchas

> [!warning] A syntax error in XferCommand breaks *every* pacman operation
> pacman.conf is parsed on each invocation. One typo and even `-Q` can fail.
> That is why step 1 makes a `.bak` first. Restore with
> `sudo cp /etc/pacman.conf.bak /etc/pacman.conf`.

> [!warning] Stale `.part`/`.aria2` files cause "invalid or corrupted package"
> After an interrupted download, aria2 leaves `<pkg>.pkg.tar.zst.part` (and
> possibly an `.aria2` control file). If the mirror's file has since changed,
> aria2 resumes against the wrong data → signature check fails:
>
> ```
> error: <file> is corrupted (invalid or corrupted package (PGP signature))
> ```
>
> The Arch Wiki's own troubleshooting entry for that error says: look for
> `.part` files — "often caused by usage of a custom `XferCommand`". Clean and
> retry:
>
> ```bash
> sudo find /var/cache/pacman/pkg/ -iname '*.part' -delete
> sudo find /var/cache/pacman/pkg/ -iname '*.aria2' -delete
> ```

> [!warning] aria2 must be installed for pacman to download anything
> Once `XferCommand` points at `/usr/bin/aria2c`, a system without aria2
> (fresh chroot, rescue boot, or accidentally uninstalled) cannot download
> anything at all. Back up the config and keep aria2 installed before assuming
> this is harmless.

> [!caution] Too many connections get you throttled, not faster
> Raise `--max-connection-per-server` in small steps and watch the mirror's
> responses. Symptom of overshoot: 403s, resets, and pacman failing the
> transaction after retries. Fast mirror → fewer, but bigger, connections win.

> [!caution] XferCommand bypasses pacman's proxy settings
> When an external downloader is in use, pacman's proxy configuration is not
> applied to it. If your network requires a proxy, pass it to aria2 yourself:
> `--all-proxy=http://user:pass@proxy:port`. Otherwise pacman silently leaks
> direct connections — relevant if you think you are behind a filtering proxy
> or a [[Arch dnscrypt-proxy — Encrypted DNS, Ad-Blocking and systemd Hardening]]-style privacy chain.

> [!caution] pacman 7 downloads run in a sandbox
> Since pacman 7, download processes run under a Landlock sandbox. In unusual
> setups this can break external downloaders with sandbox errors. The
> documented escapes live in `pacman.conf(5)`: `DisableSandboxFilesystem`,
> `DisableSandboxSyscalls`, or `DisableSandbox`. Only reach for these if you
> actually see sandbox/Landlock failures; they exist for arcane environments,
> not routine use.

> [!note] Ignore decade-old tutorials with `--check-integrity` / `--sum-check-md5`
> Those flags verify hashes only for metalink/torrent sources — plain HTTP
> package URLs gain nothing from them, and they can force pointless restarts.
> pacman validates packages itself (signature + database checksums). Drop them.

## Verification

```bash
aria2c --version && sudo grep XferCommand /etc/pacman.conf
sudo pacman -Syu
```

Expected:

- aria2c progress lines with per-connection speed (`(2/2)` split) on large
  files;
- transaction completes with `[ALPM] upgraded <pkg>` entries; no
  "failed retrieving file" or "corrupted package" errors.

```bash
grep -E '\[ALPM\] upgraded' /var/log/pacman.log | tail
```

Rollback check: comment the `XferCommand` line, run `sudo pacman -Syu`, and
confirm the built-in progress bar returns without touching anything else.

## Related

- [[Arch Pro Setup]] — pacman/paru provisioning conventions this note plugs into
- [[Arch dnscrypt-proxy — Encrypted DNS, Ad-Blocking and systemd Hardening]] — proxy/privacy angle on downloads
- [[Home]]

## Sources

- [aria2 — ArchWiki (pacman XferCommand)](https://wiki.archlinux.org/title/Aria2#pacman_XferCommand) — canonical command string and flag semantics
- [pacman — ArchWiki (Parallel downloads)](https://wiki.archlinux.org/title/Pacman#Parallel_downloads) — `ParallelDownloads` defaults (on since 7.0.0, default 5); "corrupted package" troubleshooting
- [pacman.conf(5) — Arch manual pages](https://man.archlinux.org/man/pacman.conf.5.en) — `XferCommand` `%u`/`%o` placeholders, `.part` suffix, sandbox disable options
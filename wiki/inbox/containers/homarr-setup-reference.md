---
title: "Homarr/Caddy/Podman Quick Reference"
aliases: - Homarr reference - Caddy reference - Podman reference
description: >
  Quick reference guide for Homarr dashboard with Caddy reverse proxy
  and Podman on Raspberry Pi, with Tailscale integration.
tags:
  - homarr
  - caddy
  - podman
  - quadlet
  - tailscale
  - raspberry-pi
categories: containers
type: reference
status: evergreen
created: 2026-10-30
updated: 2026-10-30
last_reviewed: 2026-10-30
review_after: 2027-01-27
language: en
audience: devops
platform:
  - Linux
  - Raspberry Pi
  - Podman
  - Caddy
  - Tailscale
keywords:
  - homarr
  - caddy
  - podman
  - tailscale
  - quadlet
  - reverse-proxy
scope: Homarr self-hosted dashboard quick reference
---
# Homarr/Caddy/Podman Quick Reference

## Current Configuration

| Component | File | Default Ports |
|---|---|---|
| **Homarr** | `~/.config/containers/systemd/homarr.container` | `PublishPort=8080:80` |
| **Caddy HTTP** | `~/.config/containers/systemd/caddy.container` | `PublishPort=80:80` |
| **Caddy HTTPS** | `~/.config/containers/systemd/caddy.container` | `PublishPort=443:443` |
| **Caddyfile** | `~/.config/containers/systemd/Caddyfile` | `reverse_proxy homarr:8080` |

## Key Files

| File | Purpose |
|---|---|
| `~/.config/containers/systemd/homarr.container` | Homarr Quadlet unit |
| `~/.config/containers/systemd/caddy.container` | Caddy Quadlet unit |
| `~/.config/containers/systemd/Caddyfile` | Caddy configuration |
| `wiki/inbox/containers/homarr-container.md` | Full documentation |

## Changing Ports

### Homarr (change host port)
Edit `~/.config/containers/systemd/homarr.container`:
```ini
PublishPort=3000:80  # Change 8080 to desired port
```
Then restart:
```bash
systemctl --user daemon-reload
systemctl --user restart homarr
```
Access at: `http://homarr:3000`

### Caddy (change host ports)
Edit `~/.config/containers/systemd/caddy.container`:
```ini
PublishPort=8080:80
PublishPort=8443:443
```
Caddyfile `reverse_proxy homarr:8080` stays the same (targets Homarr's internal port).
Then restart:
```bash
systemctl --user daemon-reload
systemctl --user restart caddy
```

## Common Commands

### Start/Stop Services
```bash
systemctl --user start homarr caddy     # Start both
systemctl --user stop homarr caddy      # Stop both
systemctl --user restart homarr caddy   # Restart both
systemctl --user daemon-reload          # Reload after config changes
```

### Check Status
```bash
systemctl --user status homarr caddy    # Service status
podman quadlet list                      # List all Quadlet units
journalctl --user -u caddy.service -f   # Caddy logs
journalctl --user -u homarr.service -f  # Homarr logs
```

### Debug Quadlet Generation
```bash
/usr/lib/podman/quadlet -dryrun -user | grep -A10 '^---caddy.service---'
/usr/lib/podman/quadlet -dryrun -user | grep -A10 '^---homarr.service---'
```

### Tailscale
```bash
tailscale up                              # Connect to Tailscale
tailscale ip                              # Show Tailscale IP
tailscale status                          # Show Tailscale status
```

## Adding New Apps

Your Raspberry Pi can run these applications (match PI model to resource needs):

| App | RAM Min | Use Case |
|---|---|---|
| **SearXNG** | 512MB | Privacy search engine (already running) |
| **Uptime Kuma** | 512MB | Uptime monitoring |
| **Pi-hole** | 512MB | Network-wide ad blocking |
| **Home Assistant** | 1GB | Smart home hub |
| **Nextcloud** | 2GB | File sharing/hosting |
| **Open WebUI** | 4GB | Local LLM Chat interface |
| **Plex/Jellyfin** | 2GB | Media streaming server |

### To add a new app:
1. Create `~/.config/containers/systemd/<app>.container`
2. Create `~/.config/containers/systemd/Caddyfile` (if web-facing)
3. Run: `systemctl --user daemon-reload && systemctl --user start <app>`
4. Access via Tailscale network

## Related Documentation

- `wiki/inbox/containers/homarr-container.md` - Full Homarr/Caddy setup
- `wiki/inbox/containers/quadlet.md` - Quadlet unit reference
- `wiki/inbox/containers/podlet-compose-to-quadlet.md` - Generate from compose.yaml
- `wiki/inbox/containers/container-registries.md` - Registry configuration
- `wiki/inbox/containers/arch-setup.md` - Baseline Arch packages

## Sources

- [Homarr documentation](https://homarr.dev/docs/)
- [Caddy documentation](https://caddyserver.com/docs)
- [Podman Quadlet docs](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Tailscale documentation](https://tailscale.com/kb/)
- [Arch Wiki - Podman](https://wiki.archlinux.org/title/Podman)
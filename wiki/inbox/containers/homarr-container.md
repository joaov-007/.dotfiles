---
title: "Homarr Dashboard with Caddy and Podman on Raspberry Pi"
aliases:
  - Homarr dashboard
  - Homarr setup
  - Caddy Homarr
  - Podman Homarr
description: >-
  Running Homarr dashboard behind Caddy reverse proxy with Podman on Raspberry Pi,
  integrated with Tailscale for secure access.
tags:
  - homarr
  - caddy
  - podman
  - quadlet
  - raspberry-pi
  - tailscale
categories: containers
type: guide
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
  - dashboard
  - caddy
  - podman
  - tailscale
scope: Homarr self-hosted dashboard with Caddy reverse proxy
---
# Homarr Dashboard with Caddy and Podman on Raspberry Pi

## Overview

This guide covers running [Homarr](https://homarr.dev/) as a self-hosted dashboard,
behind [Caddy](https://caddyserver.com/) as a reverse proxy, using [Podman](https://podman.io/)
on a [Raspberry Pi], with [Tailscale](https://tailscale.com/) for secure remote access.

## Prerequisites

- Raspberry Pi running Arch Linux ARM (or other ARM Linux)
- Podman installed and working
- Tailscale configured and running (`tailscale up`)
- Homarr Docker image (`homarr/homarr`)

## 1. Quadlet unit for Homarr

By default Homarr listens on port 80 inside the container. The host port can be changed via `PublishPort`:

```bash
cat > ~/.config/containers/systemd/homarr.container <<'EOF'
[Unit]
Description=Homarr Dashboard
After=network.target

[Container]
Image=docker.io/homarr/homarr:latest
ContainerName=homarr
# Join Tailscale network via PodmanArgs
PodmanArgs=--network=tailscale0
# Change the host port (left side) to your preferred value
# Default: 8080:80, examples: 3000:80, 8081:80, 9090:80
PublishPort=8080:80
Environment=TAILSCALE_AUTHKEY=tskey-your-auth-key

[Service]
Restart=unless-stopped

[Install]
WantedBy=default.target
EOF
```



```bash
systemctl --user daemon-reload
systemctl --user start homarr.service
systemctl --user status homarr.service
```

## 2. Caddy Quadlet unit

Create Caddy as a separate container that proxies to Homarr. Caddy's published ports can be changed:

```bash
cat > ~/.config/containers/systemd/caddy.container <<'EOF'
[Unit]
Description=Caddy reverse proxy for Homarr
After=homarr.service
Wants=homarr.service

[Container]
Image=docker.io/library/caddy:latest
ContainerName=caddy
# Publish HTTP and HTTPS on custom higher ports (change host port as needed)
# Default: 80:80 and 443:443, examples: 8080:80 and 8443:443
PublishPort=80:80
PublishPort=443:443
Volume=./Caddyfile:/etc/caddy/Caddyfile:Z
Volume=caddy-data:/data
# Join Tailscale network via PodmanArgs
PodmanArgs=--network=tailscale0
Environment=CADDY_AGREE=true

[Service]
Restart=unless-stopped

[Install]
WantedBy=default.target
EOF
```

## 3. Caddyfile configuration

Create the Caddyfile in `~/.config/containers/systemd/`:

```text
homarr {
    reverse_proxy homarr:8080
    # Tailscale handles the secure overlay network
    # No need for external HTTPS if accessing via Tailscale only
    # The `homarr:8080` target is Homarr's internal port (configured via PublishPort in homarr.container)
    # Change Caddy's host ports via caddy.container's PublishPort directives
}
```

## 4. Tailscale integration

### Install Tailscale on Raspberry Pi

```bash
# Install Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale and authenticate
sudo tailscale up --advertise-tags=tag:pi --hostname=pi-raspberry

# Check your Tailscale IP
tailscale ip
```

### Network configuration

Both Homarr and Caddy containers will join the Tailscale network via `PodmanArgs=--network=tailscale0`, allowing them to communicate using container names (`homarr:8080`) on the Tailscale overlay network.

### Accessing Homarr

Once both containers are running, access Homarr at the default port or your custom port:

**Default (port 8080):**
```
http://homarr:8080
# Or via Tailscale DNS: homarr.ts-yournet.ts.net:8080
```

**Custom port (if changed from the default):**
```
http://homarr:3000    # if you set PublishPort=3000:80
# Or via Tailscale: homarr.ts-yournet.ts.net:3000
```

The port is configured via `PublishPort=host_port:80` in `~/.config/containers/systemd/homarr.container`.

## 5. Raspberry Pi optimizations

### Memory split

For Raspberry Pi 4/5 with 4GB+ RAM, the default 256MB GPU split is fine for containers.
For Pi 3 or lower, increase `gpu_mem` in `/boot/firmware/config.txt` (or `/boot/config.txt`):

```txt
gpu_mem=512
```

### Caddy data directory

```bash
mkdir -p ~/.config/caddy/data
chmod 777 ~/.config/caddy/data
```

### Auto-start at boot

Quadlet units with `[Install] WantedBy=default.target` will start at boot if lingering is enabled:

```bash
sudo loginctl enable-linger $USER
```

## 8. Changing Default Ports

You can change the exposed ports for both Homarr and Caddy by modifying the `PublishPort` directives in their respective Quadlet unit files.

### Changing Homarr's external port

Edit `~/.config/containers/systemd/homarr.container`:

```ini
[Container]
Image=docker.io/homarr/homarr:latest
ContainerName=homarr
PodmanArgs=--network=tailscale0
# Change 8080 to any higher port you prefer
# Examples: 3000:80, 8081:80, 9090:80
PublishPort=8080:80
Environment=TAILSCALE_AUTHKEY=tskey-your-auth-key
```

**Example using port 3000:**
```ini
PublishPort=3000:80
```

After changing, reload and restart:
```bash
systemctl --user daemon-reload
systemctl --user restart homarr
```

Access Homarr at:
```
http://homarr:3000
# Or via Tailscale: homarr.ts-yournet.ts.net:3000
```

### Changing Caddy's external ports

Edit `~/.config/containers/systemd/caddy.container`:

```ini
[Container]
Image=docker.io/library/caddy:latest
ContainerName=caddy
# Change the published host ports (host:container)
# Default: 80:80 and 443:443
# Examples: 8080:80 and 8443:443, or 3000:80 and 4000:443
PublishPort=80:80
PublishPort=443:443
Volume=./Caddyfile:/etc/caddy/Caddyfile:Z
Volume=caddy-data:/data
PodmanArgs=--network=tailscale0
Environment=CADDY_AGREE=true
```

**Example using custom high ports:**
```ini
PublishPort=8080:80
PublishPort=8443:443
```

The Caddyfile `reverse_proxy homarr:8080` stays the same because it refers to Homarr's internal port, which is mapped via `PublishPort` in the Homarr container.

### Updating the Caddyfile if needed

If you change Caddy's internal HTTP/HTTPS behavior, update `~/.config/containers/systemd/Caddyfile`:

```text
# If Caddy publishes on non-default ports, the Caddyfile still uses the internal port
homarr {
    reverse_proxy homarr:8080
}
```

## 6. Validation and troubleshooting

### Check generated units

```bash
# List all Quadlet units
podman quadlet list

# Check specific units
systemctl --user status caddy.service
systemctl --user status homarr.service
```

### View logs

```bash
journalctl --user -u caddy.service -f
journalctl --user -u homarr.service -f
```

### Debug Quadlet generation

```bash
# Dry-run to see what the generator will produce
/usr/lib/podman/quadlet -dryrun -user | grep -A10 '^---caddy.service---'
/usr/lib/podman/quadlet -dryrun -user | grep -A10 '^---homarr.service---'
```

### Common issues

1. **Containers can't reach each other**: Ensure both have `PodmanArgs=--network=tailscale0`
2. **TLS not working**: With Tailscale, HTTP inside the overlay network is sufficient.
   Use `reverse_proxy` as shown; Caddy will manage internal HTTP.
3. **Permission errors**: The `:Z` flag on volumes is for SELinux relabeling.
   On Arch Linux with rootless Podman, this is usually not required.
4. **Image pull failures**: First start may take time to pull images.
   Pre-pull: `podman pull docker.io/homarr/homarr:latest`
5. **Tailscale not connecting**: Run `tailscale status` on the Pi and ensure
   the account is authorized.

## 7. Full setup checklist

- [ ] Install Podman: `sudo pacman -S podman`
- [ ] Install Tailscale and connect: `tailscale up`
- [ ] Decide on custom ports (optional):
   - Homarr: default 8080, suggest 3000/8081/9090
   - Caddy HTTP: default 80, suggest 8080/3000/9090
   - Caddy HTTPS: default 443, suggest 8443/4000/9443
- [ ] Create `~/.config/containers/systemd/homarr.container`
- [ ] Create `~/.config/containers/systemd/caddy.container`
- [ ] Create `~/.config/containers/systemd/Caddyfile`
- [ ] Enable lingering: `sudo loginctl enable-linger $USER`
- [ ] Start units: `systemctl --user start homarr caddy`
- [ ] Access Homarr at: `http://homarr:8080` (default) or your custom port (inside Tailscale network)
- [ ] First run: complete initial Homarr setup (add services, widgets, etc.)

## Related notes

- [[podlet-compose-to-quadlet]] - Generate Quadlet from compose.yaml
- [[podman-registries]] - Registry configuration for image pull
- [[arch-setup]] - Baseline Arch packages including podman
- [[container-registries]] - Container registry setup

## Sources

- [Homarr documentation](https://homarr.dev/docs/)
- [Caddy documentation](https://caddyserver.com/docs)
- [Podman Quadlet docs](https://docs.podman.io/en/latest/markdown/podman-systemd.unit.5.html)
- [Tailscale documentation](https://tailscale.com/kb/)
- [Arch Wiki - Podman](https://wiki.archlinux.org/title/Podman)
---
title: "Second Brains for Developers: Raspberry Pi + Free Cloud Services"
aliases: []
description: >-
  Options for self-hosted second brains on Raspberry Pi with free sync and remote access.
tags:
  - second-brain
  - raspberry-pi
  - self-hosted
  - syncthing
  - cloudflare
  - pkm
type: note
status: draft
created: 2026-10-26
updated: 2026-10-26
review_after: 2027-01-24
language: en
audience: maintainer
scope: ""
platform: []
keywords: []
related:
  - "[[Home]]"
cssclasses: []
---

# Second Brains for Developers: Raspberry Pi + Free Cloud Services

> [!summary] Quick answer
> For developers, Obsidian + Syncthing is the most future-proof starting point. For a web UI accessible anywhere, TriliumNext Notes is hard to beat. Both run well on a Raspberry Pi 4/5 with an SSD and can be remotely accessed for free with Cloudflare Tunnel.

## Options

| Tool | Best for | Pi fit | Sync/Remote | Notes |
| --- | --- | --- | --- | --- |
| Obsidian + Syncthing | Markdown-first, backlinks, Git-friendly, portable | Great on Pi (host sync only, not the app) | Syncthing (P2P, E2EE, free) or Git to free repo | Your notes stay plaintext. Future-proof. My recommendation to start. |
| TriliumNext Notes | Hierarchical wiki, web UI, web clipper, encryption | Good on Pi 4/5 (4GB+). Avoid Pi Zero. | Syncthing or built-in sync, expose via Cloudflare Tunnel | Feels like Notion/wiki, accessible from any browser. |
| Joplin + Joplin Server | Clean cross-platform app with E2EE | Good on Pi 4 | Self-host server, expose via Cloudflare Tunnel | Middle ground between Obsidian and Trilium. |
| AnythingLLM/PrivateGPT | RAG over notes with local LLM | Only Pi 5 8GB+ with small models; slow otherwise | Usually local; can tunnel but slow | Cool, but likely a maintenance headache on Pi. Don't start here. |

## Free Stack

1. **Hardware**: Raspberry Pi 4/5, decent PSU, SSD (avoid cheap microSD for longevity).
2. **Core**: Docker Compose with TriliumNext or just Syncthing.
3. **Sync**: [Syncthing](https://syncthing.net/) - P2P, E2EE, free, no third-party cloud account required.
4. **Remote access**: [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/) - free, no open router ports, can add Cloudflare Zero Trust auth.
5. **Backups**: [Restic](https://restic.net/) to free target (another drive or free object storage tier), scheduled.

## Tips

- **Developers**: Prefer Obsidian + Syncthing + Git. You can link to code, version-control your knowledge base, and work from your editor.
- **Don't chase AI first**: Pi is great as sync node/vault host/web app, not 30B model runner. Offload to desktop if needed.
- **Security**: If using Cloudflare Tunnel, still add auth to your app if missing. Keep containers updated.
- **Maintenance**: Keep it simple - update containers monthly, check backups. The biggest cost is attention and backups, not upgrades.

## Sources

- [Build a digitally sovereign second brain - Raspberry Pi](https://www.raspberrypi.com/news/build-a-digitally-sovereign-second-brain/)
- [TriliumNext Notes](https://github.com/TriliumNext/trilium)
- [Syncthing](https://syncthing.net/)
- [Cloudflare Tunnel](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [Free Secure Self-Hosting Using Cloudflare Tunnels](https://programmingpercy.tech/blog/free-secure-self-hosting-using-cloudflare-tunnels/)
- [How to Build an AI Second Brain (Private, Free, and Self Hosted)](https://learnwithhasan.com/guide/ai-second-brain/)

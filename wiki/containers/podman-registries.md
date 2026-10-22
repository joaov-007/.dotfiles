---
title: "Podman Registries Configuration"
aliases:
  - Podman registries
  - Container registries config
  - registries.conf
  - Podman registry setup
description: >-
  User-level Podman registries.conf snippet configuring unqualified-image search
  across all major public container registries, including Google Container Registry.
tags:
  - podman
  - containers
  - docker
  - devops
  - reference
type: reference
status: evergreen
created: 2026-09-27
updated: 2026-09-27
last_reviewed: 2026-09-27
review_after: 2027-03-27
language: en
audience: devops
scope: user-level Podman registry configuration
platform:
  - Linux
  - Podman
keywords:
  - podman
  - registries.conf
  - container registry
  - docker.io
  - quay.io
  - ghcr.io
  - gcr.io
  - ecr
  - mcr
  - unqualified-search-registries
sources:
  - "[containers-registries.conf(5)](https://man.archlinux.org/man/containers-registries.conf.5)"
source_retrieved: 2026-09-27
related:
  - "[[Home]]"
  - "[[container-registries]]"
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document Podman registries configuration"
ai-review: pending
cssclasses:
  - reference
---

# Podman Registries Configuration

Podman snippet for `~/.config/containers/registries.conf` — configures
unqualified-image search across all major public container registries.

## Configuration

Save as `~/.config/containers/registries.conf`:

```toml
# Podman registry configuration
# Generated: 2026-09-27
# Note: Google Container Registry (gcr.io) is intentionally excluded.

unqualified-search-registries = [
    "docker.io",
    "quay.io",
    "ghcr.io",
    "registry.fedoraproject.org",
    "registry.access.redhat.com",
    "registry.gitlab.com",
    "public.ecr.aws",
    "mcr.microsoft.com",
    "gcr.io"
]

[[registry]]
prefix = "docker.io"
location = "docker.io"

[[registry]]
prefix = "quay.io"
location = "quay.io"

[[registry]]
prefix = "ghcr.io"
location = "ghcr.io"

[[registry]]
prefix = "registry.fedoraproject.org"
location = "registry.fedoraproject.org"

[[registry]]
prefix = "registry.access.redhat.com"
location = "registry.access.redhat.com"

[[registry]]
prefix = "registry.gitlab.com"
location = "registry.gitlab.com"

[[registry]]
prefix = "public.ecr.aws"
location = "public.ecr.aws"

[[registry]]
prefix = "mcr.microsoft.com"
location = "mcr.microsoft.com"

[[registry]]
prefix = "gcr.io"
location = "gcr.io"
```

## Registries included

| Registry | Prefix | Use case |
|---|---|---|
| Docker Hub | `docker.io` | Largest public image library |
| Quay.io | `quay.io` | Red Hat / CNCF projects |
| GitHub Container Registry | `ghcr.io` | Images tied to GitHub repos |
| Fedora Registry | `registry.fedoraproject.org` | Fedora official images |
| Red Hat Registry | `registry.access.redhat.com` | Red Hat product images |
| GitLab Registry | `registry.gitlab.com` | GitLab CI/CD integrated |
| Amazon ECR Public | `public.ecr.aws` | AWS-published images |
| Microsoft MCR | `mcr.microsoft.com` | Microsoft product images |
| Google Container Registry | `gcr.io` | Google-published images |

## Sources
- [containers-registries.conf(5)](https://man.archlinux.org/man/containers-registries.conf.5) — documentation, authoritative

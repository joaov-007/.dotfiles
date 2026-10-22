---
title: "Container Registries"
aliases:
  - Container registries
  - Image registries
  - Docker registries
  - Registry list
  - Container image registries
description: >-
  Curated list of public container image registries for pulling and pushing
  OCI/Docker images, with primary use cases and authentication requirements.
tags:
  - containers
  - docker
  - kubernetes
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
scope: public container registries
platform:
  - Linux
  - containers
keywords:
  - container registry
  - image registry
  - docker hub
  - quay.io
  - github container registry
  - gitlab container registry
  - amazon ecr
  - azure container registry
  - docker pull
  - docker push
  - oci
  - helm registry
sources:
  - "[Docker Hub](https://hub.docker.com)"
  - "[Quay.io](https://quay.io)"
  - "[GitHub Container Registry](https://ghcr.io)"
source_retrieved: 2026-09-27
related:
  - "[[Home]]"
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to document container registries"
ai-review: pending
cssclasses:
  - reference
---

# Container Registries

Public container image registries for storing, distributing, and pulling
OCI-compatible and Docker images. Google Container Registry (gcr.io) is
intentionally excluded from this list.

## Registries

| Registry | URL | Use Case | Auth |
|---|---|---|---|
| Docker Hub | `docker.io` / `https://hub.docker.com` | Largest public image library; official and community images | Free tier; rate-limited anonymous pulls |
| GitHub Container Registry | `ghcr.io` | Images tied to GitHub repos; free for public packages | GitHub token required |
| Quay.io | `quay.io` | Red Hat's registry; strong security scanning; used by many CNCF projects | Free tier available |
| GitLab Container Registry | `registry.gitlab.com` | Integrated with GitLab CI/CD pipelines | GitLab token required |
| Amazon ECR Public | `public.ecr.aws` | AWS-hosted public images; serves AWS-published software | Anonymous pull available for public repos |
| Azure Container Registry | `*.azurecr.io` | Enterprise registry tightly integrated with Azure services | Azure auth required |
| Docker Hub Official Images | `docker.io/library` | Curated, secure base images from upstream projects | No auth required for pull |

## Quick reference

```bash
# Pull from Docker Hub
docker pull docker.io/library/nginx:latest

# Pull from GitHub Container Registry
docker pull ghcr.io/owner/image:tag

# Pull from Quay.io
docker pull quay.io/organization/image:tag

# Pull from Amazon ECR Public
docker pull public.ecr.aws/aws-cli/aws-cli:latest
```

## Notes

- All registries listed support the **OCI image spec** and Docker v2 schema.
- Rate limits apply on free tiers; authenticate to increase pull quotas.
- Google Container Registry (`gcr.io`) is excluded per maintainer preference.

## Sources
- [Docker Hub](https://hub.docker.com) — registry, authoritative
- [Quay.io](https://quay.io) — registry, authoritative
- [GitHub Container Registry](https://ghcr.io) — registry, authoritative

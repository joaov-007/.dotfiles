---
title: Home
aliases:
  - Home
  - Index
  - MOC
  - Wiki Home
description: >-
  Entry point and map of content for this wiki. Dataview-powered tables of every note by
  type, status and tag, plus review queues for stale and expiring notes.
tags:
  - index
  - moc
  - meta
type: moc
status: evergreen
created: 2026-09-27
updated: 2026-10-17
last_reviewed: 2026-10-14
review_after: 2027-03-27
language: en
audience: maintainer
related:
  - "[[Vault Conventions]]"
  - "[[Note Template]]"
cssclasses:
  - index
ai-gen: true
ai-model: "longcat-2.5-preview-free"
ai-provider: "opencode"
ai-prompt: "Initial creation from user request to create wiki home page"
ai-review: pending
scope: vault index and map of content
keywords:
  - index
  - moc
  - map of content
  - vault
platform:
  - Obsidian
---

# Home

Personal knowledge base, organised by topic folder. Every note carries YAML
frontmatter following a single schema; see [[Vault Conventions]].

> [!info] Reading this vault elsewhere
> Frontmatter is plain YAML, so Hugo, Jekyll, MkDocs, Quartz and Docusaurus all read it
> directly. The body uses Obsidian wikilinks (`[[note]]`) and callouts (`> [!warning]`),
> which are Obsidian-flavoured Markdown and will render literally elsewhere.

## Start here

| Note | What it is |
|---|---|
| [[Vault Conventions]] | Field schema, tag taxonomy, naming rules — **read before adding a note** |
| [[Note Template]] | Copy this to start a new note |
| [[arch-encrypted-swap]] | Generic reference: encrypted swap on Arch, and why resizing breaks LUKS + btrfs |
| [[arch-system-audit]] | Machine-specific audit of host `bacon` + swapfile runbook |
| [[arch-hardening-runbook]] | Security hardening for `bacon`: lynis audit, ClamAV + fangfrisch, AIDE, rootkit/backdoor forensics |
| [[system-diagnostics-and-self-healing]] | Find what is wrong on a host and automate recovery: journalctl/ACPI triage, watchdog, kdump, scrub |
| [[Arch Linux Security Hardening]] | Map of content for the 12-note hardening set: reading order, note map, consolidated checklist |
| [[arch-dnscrypt-proxy]] | Encrypted DNS on Arch: activation mode, ad-blocking, systemd sandbox drop-in, NetworkManager hand-off |
| [[dnscrypt-proxy-tor]] | dnscrypt-proxy routed over Tor for host and containers: `force_tcp` + SOCKS, own image, fail-closed ad-blocking, searxng coexistence |
| [[flatpak-apps]] | 157 verified Flathub apps, with licences and install counts |
| [[terminal-keybindings]] | Terminal and Readline key binding cheat sheet |
| [[qemu-automated-testing]] | QEMU/libvirt VM testing pipeline for dotfiles, Arch installs, niri + Noctalia setup, multi-machine tooling |
| [[Eleições Paranavaí 2026]] | Paranavaí/PR 2026 election dossier — TSE codes, candidate record *(file: `ai-elections/2026/README.md`)* |

## By topic

- **Arch Linux** — [[arch-setup]], [[archinstall-niri-packages]], [[pacman-aria2]], [[kernel-dev-debugging]], [[qemu-automated-testing]]
- **Storage & encryption** — [[arch-encrypted-swap]], [[arch-system-audit]], [[swap-encryption]], [[rsync-folder-merge]]
- **Security & hardening** — [[Arch Linux Security Hardening]] (hub), [[arch-hardening-runbook]]
- **System health & diagnostics** — [[system-diagnostics-and-self-healing]]
- **Networking & DNS** — [[arch-dnscrypt-proxy]], [[dnscrypt-proxy-tor]], [[tor]]
- **Linux desktop** — [[flatpak-apps]], [[niri-screencasting]], [[vesktop-noctalia-theme]], [[noctalia-wallpapers]]
- **Linux & kernel** — [[kernel-initramfs]], [[linux-kernel-development-tasks]], [[libvirt-virt-manager]], [[libvirt-small-vms]], [[terminal-keybindings]]
- **Firmware & hardware** — [[firmware-update-bricks]]
- **Containers** — [[Quadlet]], [[podlet-compose-to-quadlet]], [[podman-registries]], [[container-registries]], [[searxng-tor]], [[dnscrypt-proxy-podman]], [[dnscrypt-proxy-tor]], [[devcontainers-podman]]
- **Email** — [[email-clients]], [[himalaya-email-client]], [[matcha-email-client]]
- **Development** — [[rust-tools]], [[git-email-workflow]]
- **Reference & cheatsheets** — [[ascii-table]], [[Obsidian Tasks Plugin]], [[Obsidian Tasks Cheatsheet]]
- **Elections (BR)** — [[Eleições Paranavaí 2026]]

## All notes

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  type AS "Type",
  status AS "Status",
  dateformat(updated, "yyyy-MM-dd") AS "Updated",
  review_after AS "Review"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
WHERE file.path != this.file.path
  AND type != "moc"
SORT type ASC, updated DESC
```

## Needs attention

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  status AS "Status",
  dateformat(review_after, "yyyy-MM-dd") AS "Review due",
  round(date("today") - review_after, 0) AS "Days overdue"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
WHERE review_after AND review_after <= date(today) + dur(30 days)
SORT review_after ASC
```

> Currently open: `arch-system-audit` is `needs-action` with a five-step swap runbook,
> `arch-dnscrypt-proxy` is `draft` — verified against upstream sources but not yet executed on
> a live host, and the Paranavaí dossier expires after the 2026-10-04 first round.
> `dnscrypt-proxy-tor` is `draft`; the live-state report found the host **not** using its
> running local resolver (`resolv.conf` → `187.33.208.9`) and the daemon **not** Tor-routed —
> see [[dnscrypt-proxy-tor]] §1 and [[dnscrypt-tor-todos]].
> `system-diagnostics-and-self-healing` is `needs-action` with five fixes found on `bacon`
> (sysctl typo, acpi_call module, audit backlog, watchdog/panic unset).

## By status

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  type AS "Type",
  dateformat(updated, "yyyy-MM-dd") AS "Updated"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
WHERE status
SORT status ASC, updated DESC
```

## Tags in use

```dataview
LIST
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
FLATTEN tags AS tag
WHERE tag
GROUP BY tag
SORT length(rows) DESC
```

## Unlinked notes (orphans)

```dataview
LIST
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
WHERE file.path != this.file.path
  AND !length(file.inlinks)
```

Notes that carry the data profile (§2.3 of [[Vault Conventions]]).

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  methodology AS "Method",
  sample_size AS "n",
  metrics AS "Metrics",
  temporal_coverage AS "Covers",
  verified AS "Verified"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
WHERE sample_size OR data_source OR methodology
SORT sample_size DESC
```

## Dev & tooling

Notes that carry the developer profile (§2.4 of [[Vault Conventions]]).

```dataview
TABLE WITHOUT ID
  file.link AS "Note",
  runtime AS "Runtime",
  entrypoint AS "Entrypoint",
  version AS "Version"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"
WHERE entrypoint OR deps OR runtime
SORT file.name ASC
```

## Conventions

- One note per topic, in a topic folder (`storage/`, `ai-elections/<year>/`, up to three levels
  such as `arch-linux/hardening/<domain>/`).
- `scripts/` holds non-note attachments (shell, systemd units); `templates/` holds Obsidian
  skeletons; `AGENTS.md` is agent configuration; `.obsidian/` is app config; `_clones/` and
  `__clones/` hold upstream Git repositories/external wikis. All are excluded from search, the
  graph, and every query above (`-"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"`).
- The schema is **core + profiles**: eight required core fields that never change, and optional
  fields grouped into named profiles (data, dev, machine, sources, AI) — see [[Vault Conventions]] §2.
- Filename is the note identity: `kebab-case.md`, no dates, no `v2`.
- Dates are ISO `YYYY-MM-DD`, unquoted.
- Tags are flat `kebab-case` — no `#`, no `/` nesting (portable to every SSG).
- Every standard property is flat and typed in `.obsidian/types.json`, so the Properties panel
  renders date pickers, checkboxes and number fields.
- `related:` holds `[[wikilinks]]`; a link to a note that does not exist yet is an
  intentional topic placeholder, not a typo.

## Kepano/zakatesh Categories Organization

This wiki has been reorganized following the **Kepano/zakatesh methodology** (the note-taking system used by the Obsidian CEO, Steph Ango). Key principles:

### Categories Property (Primary Organization)
Notes are organized via the `categories` YAML property rather than deep folder hierarchies. Each note has a `categories:` field linking it to its topic area:

| Category | Example Notes |
|---|---|
| `arch-linux` | arch-setup, kernel-dev-debugging, pacman-aria2 |
| `containers` | container-registries, devcontainers-podman, quadlet |
| `development` | git-email-workflow, rust-tools |
| `email` | email-clients, himalaya-email-client, matcha-email-client |
| `linux` | kernel-initramfs, terminal-keybindings |
| `storage` | arch-encrypted-swap, arch-system-audit |
| `desktop` | niri-screencasting, vesktop-noctalia-theme |
| `networking` | arch-dnscrypt-proxy |

### Inbox Folder
- **`inbox/`**: New notes and notes needing triage
- **Workflow**: Create notes in `inbox/`, add `categories` property, then move to root when ready
- Keeps the vault root uncluttered while notes are being drafted

### Minimal Folders (Kepano Style)
- `inbox/` - New/untriaged notes
- `attachments/` - Images, audio, video, PDFs
- `clippings/` - External content/clippings
- `daily/` - YYYY-MM-DD daily notes
- `notes/` - Example notes per Kepano's system

All other content notes reside in the vault root with the `categories` property, following the principle that **properties over folders** drive organization.

### Using Categories for Discovery
Your wiki now supports Dataview queries to find notes by category:

```dataview
# See all container-related notes
LIST WHERE contains(categories, "containers")

# View the category overview (Maps of Content)
# Open categories/containers.md in Obsidian
```

### Creating New Notes (Frictionless Workflow)

```bash
# 1. Create note in inbox (Kepano's speed-first approach)
cp templates/note-template.md inbox/my-new-note.md

# 2. Fill frontmatter, then add categories property
#    Edit frontmatter to add: categories: my-topic

# 3. Move to root when ready (or keep in inbox until triaged)
mv inbox/my-new-note.md my-new-note.md

# 4. Git sync
git add my-new-note.md
git commit -m "docs: add new note about ..."
git push origin dev
```

### Category Overview Files (New MOCs)
Eight new category overview files were created in `categories/`:
- `categories/arch-linux.md` - Map of all Arch Linux notes
- `categories/containers.md` - Map of container/Podman notes
- `categories/desktop.md` - Map of desktop/notes
- `categories/development.md` - Map of development/tooling notes
- `categories/email.md` - Map of email client notes
- `categories/linux.md` - Map of Linux/kernel notes
- `categories/networking.md` - Map of networking/DNS notes
- `categories/storage.md` - Map of storage/encryption notes

These serve as entry points for exploring notes by topic, following the Kepano emphasis on **Bases and properties** for navigation rather than folder hierarchies.

### Kepano Philosophy Applied

This reorganization rejects the "Wikipedia project" mentality of:
- Rigid table of contents
- Deep folder hierarchies
- Obsessive wikilink tracking

Instead it embraces:
- **Properties over links** for organization structure
- **Speed and laziness** - minimal overhead
- **Emergent structure** - categories emerge naturally
- **File-over-app** - notes are just Markdown files you control
- **Fractal journaling** - the `daily/` and `inbox/` support the fractal review pattern
- **Minimal folders** - only `inbox`, `attachments`, `clippings`, `daily`, `notes`

### Backward Compatibility
Existing folder structures (`arch-linux/`, `linux/`, etc.) are **retained** for notes that were already organized that way. The `categories` property adds a new organization layer without requiring migration of existing notes. New notes should use the `categories` property per the Kepano methodology.

### Reference
- [Lessons From Breaking Down Obsidian's CEO's Personal Vault](https://parazettel.com/articles/what-i-learned-after-kepano-vault/) - Parazettel article analyzing Kepano's vault system
- [How I use Obsidian - Steph Ango](https://stephango.com/vault) - Original vault description

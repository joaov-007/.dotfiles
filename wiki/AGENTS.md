# AGENTS.md — Wiki Agent Instructions

**The single source of truth for this vault is [`meta/vault-conventions.md`](meta/vault-conventions.md).**
Field schema, controlled vocabularies (`type`, `status`, `confidence`), tag taxonomy,
naming rules, and the Dataview cookbook all live there. Read it before adding or
editing a note. Do not maintain a second schema in this file.

## Purpose

This file provides agent instructions for working with this Obsidian knowledge vault.
It documents the vault structure, conventions, workflows, and operational rules
so an AI agent can operate safely and consistently without breaking existing patterns.

## Vault Overview

This is a personal knowledge wiki built with [Obsidian](https://obsidian.md/).
It follows a topic-based folder structure with a lean frontmatter schema,
Dataview-powered MOCs (Maps of Content), and is designed for portability to
static site generators (Hugo, Jekyll, MkDocs, Quartz, Docusaurus, Pandoc).

The entry point is [`Home.md`](Home.md), which serves as the MOC and index.

## Layout

```
Wiki/
├── Home.md                    # Map of content (MOC), the entry point
├── meta/                      # Schema + working trackers
│   ├── vault-conventions.md   # Canonical schema (READ THIS FIRST)
│   ├── obsidian-tasks-plugin.md # Obsidian Tasks plugin guide
│   ├── obsidian-tasks-plugin-cheatsheet.md # Tasks plugin cheatsheet
│   └── hardening-todos.md     # Working task tracker
├── templates/                 # Obsidian Templates plugin folder
│   └── note-template.md       # Canonical note skeleton
├── arch-linux/                # Arch Linux specific notes
│   ├── arch-setup.md
│   ├── archinstall-niri-packages.md
│   ├── kernel-dev-debugging.md
│   ├── pacman-aria2.md
│   ├── qemu-automated-testing.md
│   ├── hardening/             # Security hardening (split into domains)
│   │   ├── arch-linux-hardening.md   # Hub MOC (reading order, checklist)
│   │   ├── arch-hardening-runbook.md # Host-specific audit + runbook
│   │   ├── foundations/       # Threat model, lifecycle
│   │   ├── disk/              # Encryption, filesystem, physical
│   │   ├── boot/              # Boot, Secure Boot
│   │   ├── kernel/            # Kernel hardening
│   │   ├── access/            # AuthN, AuthZ, MAC (AppArmor), PAM, sudo
│   │   ├── network/           # Firewall, SSH, DNS/privacy
│   │   ├── services/          # systemd, sandboxing
│   │   └── detection/         # Auditing, integrity, rootkits
│   └── services/              # Arch services (tor)
├── linux/                     # Distro-agnostic Linux topics
│   ├── kernel-initramfs.md
│   ├── libvirt-virt-manager.md
│   └── terminal-keybindings.md
├── storage/                   # Storage, LUKS, btrfs, swap, file sync
│   ├── arch-encrypted-swap.md
│   ├── arch-system-audit.md
│   ├── swap-encryption.md
│   └── rsync-folder-merge.md
├── networking/                # Networking, DNS, DNSCrypt
├── containers/                # Podman, Quadlet, container registries
├── desktop/                   # Wayland desktop: niri, Noctalia, Flatpak
│   ├── niri-screencasting.md
│   ├── noctalia-wallpapers.md
│   ├── vesktop-noctalia-theme.md
│   └── flatpak/               # Flatpak catalogue, permissions, personal list
├── email/                     # Email clients and recommendations
├── development/               # Dev tooling and workflows (git, rust)
├── reference/                 # Lookup tables and cheatsheets
├── scripts/                   # Shell scripts + systemd units (non-note attachments)
├── ai-elections/2026/         # Election research dossier
├── _clones/                   # Upstream Git clones (NOT notes) — for OSS curricula
├── __clones/                  # Additional third-party Git clones/wikis (NOT notes) — for other wikis/sources
├── .backup/                   # Backups of pre-reorganisation tree (excluded)
└── .obsidian/                 # Obsidian configuration (workspace, theme, snippets)
```

### Notable directories explained

- **`meta/`** — Canonical schema, conventions, and working trackers. `vault-conventions.md` defines everything. Obsidian plugin notes (`obsidian-tasks-plugin.md` and `obsidian-tasks-plugin-cheatsheet.md`) live here.
- **`templates/`** — Obsidian Templates plugin looks here. Always start from `note-template.md`.
- **Obsidian plugin notes** — see `meta/obsidian-tasks-plugin.md` and `meta/obsidian-tasks-plugin-cheatsheet.md` for the Tasks plugin.
- **`arch-linux/` vs `linux/`** — Distro-specific notes live in `arch-linux/` (including the `hardening/` subtree); distro-agnostic Linux notes live in `linux/`. Cross-distro technology domains (`storage/`, `networking/`, `containers/`, `desktop/`, `email/`, `development/`, `reference/`) sit in their own top-level folders.
- **Topic folders, not format folders.** Notes are filed by subject. Note format is expressed with the `type:` field (`guide`, `runbook`, `cheatsheet`, …) — do not create `tutorial/`-style folders that duplicate it.
- **`scripts/`** — Non-note file attachments (shell scripts, systemd `.service`/`.timer` files). Obsidian ignores non-`.md` files; these are tracked in git but not treated as notes.
- **`_clones/`** — Contains upstream Git repositories (e.g., OSSU curricula: `ossu-computer-science`, `ossu-precollege-math`, UBL courses). These are **not notes**, are excluded from Obsidian search/graph, and from all Dataview queries.
- **`__clones/`** — Additional clones of other wikis, external knowledge bases, or third-party documentation sources (double underscore convention). Also **not notes**, excluded from search/graph and Dataview queries. Use this for secondary external references separate from the primary `_clones/`.
- **`.backup/`** — Compressed archives of the pre-reorganisation tree. Excluded from Obsidian and queries.

## Core Rules

### Creating and editing notes

1. **Always start from the template.** Copy `templates/note-template.md` for every new note. Never create notes from scratch.
2. **Use proper naming.** Files: `kebab-case.md`. Folders: lowercase `kebab-case`. No spaces, no capitals, no dates, no `v2`, no `final`, no copy suffixes.
3. **Place in the right folder.** File under an appropriate topic folder. Follow the existing taxonomy.
4. **One note per topic.** Keep notes focused and atomic.
5. **H1 must match title.** The first heading must match the `title:` field in frontmatter (minus folder paths).
6. **Use the lean frontmatter schema.** Eight fields are required — `title`, `tags`, `type`, `status`, `created`, `updated`, `review_after`, `related` — as defined in [`meta/vault-conventions.md`](meta/vault-conventions.md) §2. Everything else is optional. Dates are ISO `YYYY-MM-DD` and **unquoted**.
7. **Supersede, don't duplicate.** Edit existing notes in place. If fully replaced, set old note to `status: archived` and move to an archive location if needed—don't create `-v2` copies.

### Links and placeholders

- **`related:` holds `[[wikilinks]]`.** This is the canonical field for relationships between notes.
- **Unresolved wikilinks are intentional.** Links to notes that don't exist yet are **topic placeholders**, not broken links to fix. They seed the graph and mark future work.
- **Bidirectional linking encouraged.** Add reciprocal links where practical.

### Clones and excluded content

- **`_clones/` and `__clones/` are NOT notes.** They contain upstream Git repositories and external wiki clones.
- **Always exclude clones from Dataview.** Scope every `FROM` clause with `FROM -"_clones" -"__clones" -"templates"` to keep queries clean.
- **Excluded from Obsidian.** These paths are filtered in `.obsidian/app.json` (`userIgnoreFilters`) and `.obsidian/graph.json` (`search` excludes). Do not treat files inside clones as vault notes.
- **Treat clones as read-only references.** Do not edit files inside `_clones/` or `__clones/` unless explicitly instructed to contribute upstream.

### Attachments vs notes

- **`scripts/` contains non-note attachments.** Shell scripts, systemd units (`.service`, `.timer`), etc. These are tracked in git but Obsidian treats non-`.md` as attachments.
- **Keep attachments organized by purpose.** Scripts live in `scripts/`; images/assets referenced by notes live alongside as needed, but prefer keeping large external assets in appropriate locations.

## Body Structure

Required: an **H1** matching `title:`, and a **one-line summary callout** (`> [!summary]` or
`> [!info]`). The rest is optional — add only the sections a note needs, in this order where
useful:

1. **H1** matching `title:`
2. **Summary callout** — `> [!summary]` or `> [!info]` with the one-paragraph conclusion
3. **Context** — when/why this is relevant
4. **Details** — main body with `###` subsections, numbered steps for procedures
5. **Gotchas** — `> [!warning]` / `> [!danger]` about common mistakes
6. **Verification** — how to confirm it worked (expected output, not just commands)
7. **Related** — prose links to related notes
8. **Sources** — citations with what they support

## Tagging Conventions

- **Tags are topics only.** Never tag with `type` or `status` values (e.g., don't use `#reference` or `#evergreen`). Those are structured fields.
- **Flat, kebab-case.** No `#` prefix in YAML, no `/` nesting (not portable to SSGs). Use bare `kebab-case` strings.
- **Document new tags.** If introducing a new tag, add it to §5 of [`meta/vault-conventions.md`](meta/vault-conventions.md).
- **See full taxonomy.** Current tag vocabulary is maintained in the conventions file.

## Obsidian Configuration

Required/core plugins in use (see `.obsidian/core-plugins.json`):

- Dataview (community) — Powers MOC queries in `Home.md`. Essential.
- Templates (core) — Points to `templates/` folder.
- Properties, Graph, Backlinks, Outgoing links, Tag pane, Outline, Bookmarks, File explorer, etc.

CSS snippets: `noctalia.css` in `.obsidian/snippets/` provides theming (Tokyo Night-inspired). CSS classes like `nota-longa`, `wide-table`, `cheatsheet`, `index`, `reference`, `template` are used in `cssclasses:`.

## Dataview Rules

- **Always exclude clones.** Use `FROM -"_clones" -"__clones" -"templates"` in all Dataview queries.
- **Dates are unquoted ISO.** Enables proper date sorting/comparison.
- **Follow existing patterns.** See [`Home.md`](Home.md) and §10 of conventions for cookbook examples.

## Backups

Before bulk moves, renames, or major reorganisation, create a timestamped backup excluding excluded paths:

```bash
mkdir -p .backup
tar czf ".backup/wiki-$(date +%Y%m%d-%H%M%S).tar.gz" \
  --exclude='./.backup' \
  --exclude='./_clones' \
  --exclude='./__clones' \
  --exclude='./.obsidian/workspace.json' \
  --exclude='./.obsidian/workspace-mobile.json' \
  .
```

> Note: Workspace files change frequently; excluding them is often cleaner for backups, but include if you need exact UI state.

## Workflow Checklist for Adding a Note

1. Read [`meta/vault-conventions.md`](meta/vault-conventions.md) (schema, vocabularies, tags).
2. Copy `templates/note-template.md` to the appropriate topic folder.
3. Rename to `kebab-case.md`.
4. Fill the eight required frontmatter fields per §2 of conventions. Set `review_after` appropriately (6 months for evergreen technical refs, ~1 month for volatile content).
5. Write the H1 and one-line summary; add other body sections only as they help.
6. Add at least one `related:` wikilink (bidirectional if practical).
7. If new tags/types/statuses introduced, update conventions file §4–§5.
8. Verify links resolve as expected (unresolved = intentional placeholders only).

## Portability Notes

- **YAML frontmatter:** Portable to all SSGs.
- **`[[wikilinks]]`:** Obsidian-only (render literally elsewhere). Can be converted mechanically to `[text](path.md)`.
- **Callouts (`> [!type]`):** Obsidian-specific; convert to blockquotes if exporting.
- **Dataview blocks:** Obsidian-only (query text is readable).
- **Tasks, tables, code fences:** CommonMark/GFM compatible.

## References

- [Vault Conventions](meta/vault-conventions.md) — Canonical schema and rules
- [Note Template](templates/note-template.md) — Starting point for all notes
- [Home](Home.md) — MOC and index with Dataview queries
- [Obsidian Help](https://help.obsidian.md/) — Obsidian features and plugins
- [Dataview](https://blacksmithgu.github.io/obsidian-dataview/) — Query language docs
- [Arch Wiki](https://wiki.archlinux.org/) — Primary source for Arch-specific content (used throughout)
- [Man pages](https://man.archlinux.org/) — Preferred over tutorials for system commands

## Principles

- **Clarity over cleverness.** Write for future-you and others. Prefer explicit, copy-pasteable commands with verification.
- **Minimise steps, maximise clarity.** No unnecessary abstraction.
- **Verify everything.** Include verification steps after changes. Provide rollback guidance where destructive.
- **Respect existing patterns.** Consistency > novelty. Match surrounding code/style/structure.
- **Treat unfamiliar content as user work.** Investigate before modifying or deleting.
- **Single source of truth.** If conventions and this file conflict, [`meta/vault-conventions.md`](meta/vault-conventions.md) wins.
- **Unresolved links are fine.** They're placeholders intentionally.
- **Clones stay excluded.** Both `_clones/` and `__clones/` must remain out of search, graph, and Dataview queries.

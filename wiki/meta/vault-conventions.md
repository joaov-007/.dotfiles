---
title: Vault Conventions
aliases:
  - Vault Conventions
  - Conventions
  - Frontmatter Schema
  - Schema
description: >-
  The contract every note follows: an unchangeable core of eight required fields, optional
  fields grouped into named profiles (data, dev, machine, sources, AI), one field registry,
  Obsidian property types for the whole set, controlled vocabularies, a flat tag taxonomy,
  and the Dataview/Bases queries that depend on them.
tags:
  - meta
  - schema
  - documentation
  - conventions
type: reference
status: evergreen
created: 2026-09-27
updated: 2026-10-17
last_reviewed: 2026-10-17
review_after: 2027-03-27
language: en
audience: maintainer
keywords:
  - frontmatter profiles
  - field registry
  - core schema
  - data profile
  - developer profile
related:
  - "[[Home]]"
  - "[[Note Template]]"
  - "[[arch-encrypted-swap]]"
  - "[[arch-system-audit]]"
  - "[[arch-dnscrypt-proxy]]"
  - "[[flatpak-apps]]"
  - "[[terminal-keybindings]]"
cssclasses:
  - reference
ai-gen: true
ai-model: "big-pickle"
ai-provider: "opencode"
ai-prompt: "Rework the schema into a core + named-profiles model with a single field registry and a developer profile"
ai-review: pending
scope: frontmatter schema and authoring rules for this vault
platform:
  - Obsidian
---

# Vault Conventions

The contract for every note in this vault. If a note and this document disagree, this document
wins. Copy [[Note Template]] to start a note; [[Home]] is the front door.

> [!summary] The deal
> The schema has **two layers**. The **core** is eight required fields that never change. Everything
> else lives in **named profiles** — opt-in blocks of related fields (data, dev, machine, sources,
> AI) you add when a note earns them. Adding a profile never touches the core and never breaks an
> existing query; it only adds columns queries can opt into. Every standard field is listed once in
> the **field registry** (§2.8) and typed once in `.obsidian/types.json`, so the Properties panel
> and Bases read it directly.

## 1. Design goals

1. **Obsidian-native** — properties, `[[wikilinks]]`, callouts, Bases and Dataview all work; the
   Properties panel renders every standard field with the right widget.
2. **Portable YAML** — the frontmatter is plain YAML 1.2 that Hugo, Jekyll, MkDocs, Quartz,
   Docusaurus and Pandoc read unchanged.
3. **Queryable, not bureaucratic** — the required set is exactly what [[Home]]'s queries need.
   Add a field when it earns its keep, never out of habit.
4. **Extensible without breakage** — new fields are added inside profiles, the core is frozen at
   eight, and the registry (§2.8) is the single place a field is declared. Extension is a
   four-step contract (§11), not a free-for-all.

---

## 2. Frontmatter

### 2.1 Required core — eight fields

These are the note's identity and the columns every query reads. They are never optional and
never renamed.

| Field | Obsidian type | Meaning |
|---|---|---|
| `title` | text | the note's title; must match the H1 |
| `tags` | tags | flat topic tags (§5) |
| `type` | text | what kind of note — one of §4 |
| `status` | text | lifecycle state — one of §4 |
| `created` | date | ISO `YYYY-MM-DD`, unquoted |
| `updated` | date | bump on every substantive edit |
| `review_after` | date | when the note is due for re-verification |
| `related` | list | quoted `[[wikilinks]]`; unresolved links are intentional (§7) |

### 2.2 The profile model

Optional fields are not a grab-bag. They are grouped into **profiles**: named blocks of related
fields you opt into. The four heavy profiles — `data`, `dev`, `machine`, `ai` — plus any bespoke
block go at the end of the frontmatter under a comment banner. The light groups (`display`,
`lifecycle`, `sources`) sit inline in the canonical key order (§2.10).

```yaml
# --- core (always) ----------------------------------------------------------
title: "Encrypted Swap on Arch"
tags: [arch-linux, luks, swap]
type: guide
status: evergreen
created: 2026-09-27
updated: 2026-10-17
review_after: 2027-03-27
related:
  - "[[arch-system-audit]]"
# --- data profile (§2.3) ----------------------------------------------------
methodology: manual-audit
sample_size: 1
verified: true
```

Why profiles: a note with no profiles is exactly the core eight; a note can carry one profile or
five. Because every field is declared in the registry and typed in `.obsidian/types.json`, adding
a profile is additive — the Properties panel and Bases pick it up, and no existing query changes
meaning.

| Group | Add it when | Fields | Banner? |
|---|---|---|---|
| core | always | the eight fields above | no |
| display | always useful | `aliases` `description` `cssclasses` `language` `audience` `scope` `platform` | no |
| lifecycle | the note has a review or expiry story | `confidence` `last_reviewed` `expires` | no |
| sources | facts are traceable to a citation | `keywords` `sources` `source_retrieved` `source_last_edited` | no |
| **data** | the note is *about data* — catalogue, audit, dossier, measured result | §2.3 | yes |
| **dev** | the note is about code, tooling, or a runnable project | §2.4 | yes |
| machine | host-specific audit, runbook, or diagnostics | §2.5 | yes |
| ai | the note was AI-drafted | §2.6 | yes |
| bespoke | anything you invent | §2.7 | yes |

### 2.3 Data profile

Optional, flat, Obsidian-native. Add it when a note reports data — a catalogue, an audit, a
dossier, a benchmark. Values come from the note's own content; never invent them.

| Field | Type | Meaning |
|---|---|---|
| `methodology` | text | how the evidence was gathered (§4) |
| `data_source` | list | the dataset / API / registry the facts come from (quoted links) |
| `sample_size` | number | `n` — records, apps, hosts, rows counted |
| `temporal_coverage` | text | the period the data covers (`2022, 2026`) |
| `geography` | text | spatial scope (`global`, `Brasil/PR`) |
| `tools` | list | tooling that produced the note (`lynis`, `mcp-brasil`) |
| `runtime` | text | language/runtime that ran the analysis (`python`, `sql`, `r`) |
| `seed` | number | RNG seed, so the result replays (`0` is meaningful) |
| `metrics` | list | computed results, one per entry, written `name = value` |
| `verified` | checkbox | a human re-checked the claims against the source |
| `verification_method` | text | how it was verified |
| `reproducible` | checkbox | the result can be regenerated from the stated source |
| `notebook` | text | link to the notebook / script that produced the numbers |
| `repo` | text | where the code, data, or scripts live |
| `limitations` | list | known caveats |
| `findings` | list | structured results — see the record shape in §4 |
| `actions` | list | outstanding fixes derived from the findings — §4 |

`findings` and `actions` stay flat lists of maps; their keys are fixed by §4 so queries can read
`severity` and `status` without surprises.

### 2.4 Developer profile

The mirror of the data profile for notes about code and tooling — the parser series, kernel
debugging, QEMU pipelines, git workflows, packaged tools. Add it when a reader will clone, build,
or run the thing.

| Field | Type | Meaning |
|---|---|---|
| `runtime` | text | primary language/runtime (`c`, `rust`, `bash`, `python`) |
| `repo` | text | source repository (URL or quoted wikilink) |
| `entrypoint` | text | the file or command that starts it (`make`, `main.c`, `just test`) |
| `deps` | list | key dependencies (`libc`, `nftables`, `tokio`) |
| `package` | list | package names, prefixed by ecosystem (`pacman:aria2`, `cargo:ripgrep`) |
| `version` | text | the version this note targets (`1.2.3`, `7.2.9-arch1-1`) |
| `license` | text | SPDX identifier (`MIT`, `GPL-3.0-only`) |

`runtime` and `repo` are shared with the data profile — one registry entry, used wherever it
applies. Put them in the first applicable block.

### 2.5 Machine profile

For audits, runbooks and diagnostics that describe a **specific host**. It exists so the nested
`environment:` map (which Obsidian cannot edit) gets replaced by flat, editable fields.

| Field | Type | Meaning |
|---|---|---|
| `host` | text | hostname (`bacon`) |
| `os` | text | distribution/OS (`Arch Linux`) |
| `kernel` | text | `uname -r` output |
| `hardware` | text | device / CPU / RAM summary (`nvme0n1, 7.53 GiB`) |

### 2.6 Sources and AI provenance

**Sources** — carry them when a claim is traceable: `keywords` (search terms), `sources` (a flat
list of `[title](url)` links), `source_retrieved` and `source_last_edited` (dates). Per-source
detail (author, `kind`, `authoritative`) belongs in the body `## Sources` section, not frontmatter.

**AI provenance** — required on AI-drafted notes: `ai-gen` (checkbox), `ai-model`, `ai-provider`,
`ai-prompt`, `ai-review` (`pending` / `reviewed`).

### 2.7 Bespoke blocks

Anything you invent goes last, under a banner comment, and is treated as **data, not prose**.
Besoke fields are not in the registry and are not typed — which is exactly why a nested one is a
last resort: Obsidian has no property type for nested objects, so a map renders as raw JSON and is
not editable in the Properties panel. Flatten what you can; promote what you reuse into a
registered profile field (§11).

```yaml
# --- bespoke: identifiers (note-specific data, not a standard field) ---------
identifiers:
  luks2_uuid: 474a4e02-...
```

### 2.8 Field registry

The single declaration of every standard field: its Obsidian type and the profile(s) it belongs to.
If a field is not here, it is bespoke (§2.7). This table and `.obsidian/types.json` are kept in
lockstep (§11).

| Field | Obsidian type | Profile | Meaning |
|---|---|---|---|
| `title` | text | core | note title; matches the H1 |
| `tags` | tags | core | flat topic tags |
| `type` | text | core | §4 |
| `status` | text | core | §4 |
| `created` | date | core | ISO, unquoted |
| `updated` | date | core | bump on edit |
| `review_after` | date | core | re-verification due date |
| `related` | list | core | quoted wikilinks |
| `aliases` | list | display | alternate names for the linker |
| `description` | text | display | one-line summary |
| `cssclasses` | list | display | CSS snippet hooks |
| `language` | text | display | note language (`en`) |
| `audience` | text | display | who it is for |
| `scope` | text | display | what it covers |
| `platform` | list | display | target platforms |
| `confidence` | text | lifecycle | `high` / `medium` / `low` |
| `last_reviewed` | date | lifecycle | last human review |
| `expires` | date | lifecycle | hard expiry |
| `keywords` | list | sources | search terms |
| `sources` | list | sources | `[title](url)` links |
| `source_retrieved` | date | sources | when fetched |
| `source_last_edited` | date | sources | when the source changed |
| `methodology` | text | data | how evidence was gathered |
| `data_source` | list | data | dataset/API links |
| `sample_size` | number | data | `n` |
| `temporal_coverage` | text | data | period covered |
| `geography` | text | data | spatial scope |
| `tools` | list | data | tooling used |
| `runtime` | text | data · dev | language/runtime |
| `seed` | number | data | RNG seed |
| `metrics` | list | data | `name = value` results |
| `verified` | checkbox | data | human-verified |
| `verification_method` | text | data | how |
| `reproducible` | checkbox | data | regenerable |
| `notebook` | text | data | notebook/script link |
| `repo` | text | data · dev | where the code lives |
| `limitations` | list | data | caveats |
| `findings` | list | data | `{id, severity, status, detail}` |
| `actions` | list | data | `{id, status, command}` |
| `entrypoint` | text | dev | start file/command |
| `deps` | list | dev | key dependencies |
| `package` | list | dev | package names |
| `version` | text | dev | version targeted |
| `license` | text | dev | SPDX id |
| `host` | text | machine | hostname |
| `os` | text | machine | distribution |
| `kernel` | text | machine | kernel release |
| `hardware` | text | machine | device/CPU/RAM summary |
| `ai-gen` | checkbox | ai | AI-drafted |
| `ai-model` | text | ai | model name |
| `ai-provider` | text | ai | provider |
| `ai-prompt` | text | ai | originating prompt |
| `ai-review` | text | ai | review state |
| `categories` | list | display | reserved for grouped catalogues |

### 2.9 Rules that are not negotiable

- **Dates** are ISO `YYYY-MM-DD` and **unquoted**, so the Properties panel and Bases type them
  as dates.
- **Wikilinks inside frontmatter are quoted**: `related: ["[[Note]]"]`. Unquoted, YAML parses
  `[[Note]]` as a nested list and Obsidian renders no link.
- **Long prose** uses folded scalars (`>-`), never a quoted one-liner.
- **Quote** any string value containing `: ` or ` #`.
- **`sources` is a flat list of `[title](url)` links.** Per-source detail belongs in the body
  `## Sources` section, not in frontmatter.
- **No `date:`** — it is `created:`. **No `relacionados:`** — it is `related:`. [[Home]] and the
  cookbook depend on both spellings.
- **Keys follow the canonical order** (§2.10) so the Properties panel reads the same way in every
  note.
- **A field that is not in the registry (§2.8) is bespoke.** Bespoke blocks sit last, under a
  banner, and are treated as data.
- **The core eight never change.** Extension happens inside profiles.

### 2.10 Canonical key order

`title` → `aliases` → `description` → `tags` → `type` → `status` → `confidence` → `created` →
`updated` → `last_reviewed` → `review_after` → `expires` → `language` → `audience` → `scope` →
`platform` → `keywords` → `sources` → `source_retrieved` → `source_last_edited` → `related` →
`cssclasses` → *data profile* → *dev profile* → *machine profile* → *AI provenance* →
*bespoke blocks*.

---

## 3. Body

Two things are required: the **H1 matches `title:`**, and there is a **one-line summary callout**
at the top. Everything after that is optional — add the sections a note actually needs.

| Section | Use it when |
|---|---|
| `> [!summary]` or `[!info]` | always — the one-paragraph answer |
| `## Context` | the reader needs a reason to care |
| `## Details` | the body; `###` numbered steps for procedures |
| `## Method` | a data note — how it was gathered (mirrors `methodology`) |
| `## Results` | a data note — the findings/metrics, tabular where possible |
| `## Commands` | a dev note — copy-paste invocations, one per task |
| `## Snippets` | a dev note — annotated code for a reader who will adapt it |
| `## Gotchas` | there are traps worth flagging |
| `## Verification` | there is a way to confirm success |
| `## Related` | prose links beyond `related:` |
| `## Sources` | claims traceable to a citation (title, link, kind, what it supports) |

**Code fences always declare a language.** Shell is `bash`, not a bare fence. Show expected output
in its own fence or as a comment, never glued to the command.

Callout vocabulary:

| Callout | Use for |
|---|---|
| `[!summary]` `[!success]` | the headline finding |
| `[!info]` `[!note]` `[!tip]` | context, a caveat, an optimisation |
| `[!warning]` | avoidable pain / silent breakage |
| `[!danger]` | irreversible damage if ignored |
| `[!caution]` | a specific interaction that surprises people |
| `[!important]` | the root cause, stated plainly |

---

## 4. Controlled vocabularies

Closed sets — a new value needs a decision here first.

### `type`

| Value | Meaning |
|---|---|
| `reference` | canonical explanation of a topic |
| `audit` | point-in-time inspection of a real system |
| `runbook` | ordered procedure to be executed |
| `cheatsheet` | dense lookup table |
| `reference-list` | curated catalogue |
| `guide` | task-oriented walkthrough |
| `dossier` | compiled research on a subject |
| `experiment` | a reproducible test with inputs and measured output |
| `moc` | map of content |
| `template` | skeleton to copy |
| `note` | anything else |

### `status`

| Value | Meaning |
|---|---|
| `evergreen` | true long-term; unlikely to need review soon |
| `draft` | incomplete or unverified |
| `needs-action` | accurate, but has outstanding work |
| `review` | due for re-verification |
| `archived` | superseded; kept for history |

### `confidence`

`high` (primary sources, verified) · `medium` (some gaps) · `low` (speculative). Required only
when `type` is `audit`, `dossier`, or `experiment`.

### `methodology`

Free-text in practice, but reuse one of these so queries group cleanly:

`api-extraction` · `manual-audit` · `doc-review` · `field-observation` · `benchmark` ·
`experiment` · `literature-review` · `compiled` (aggregated from other notes)

### Structured records

Three list fields carry maps. Keep the keys exactly these so queries stay stable:

- `findings` — `id`, `severity` (`info` · `low` · `medium` · `high` · `critical`), `status`
  (`open` · `fixed` · `waived`), `detail` (or `summary`).
- `actions` — `id`, `status` (`pending` · `done` · `optional`), `command`.
- `metrics` — one `name = value` string per entry (e.g. `p50 latency = 12 ms`).

### `runtime` (open)

Reuse a value when one fits: `c` · `rust` · `bash` · `python` · `sql` · `r` · `javascript`.

---

## 5. Tags

> [!important] Tags are topics only
> `type` and `status` are already structured fields. Do **not** tag them (`#reference`,
> `#evergreen`) — two sources of truth drift.

Flat, `kebab-case`, **no `#` prefix and no `/` nesting** (so YAML round-trips and every SSG
reads them; [[Home]]'s tag cloud groups by exact string).

The vocabulary is **open, not enforced**: reuse an existing tag when one fits; introduce a new
one only for a real topic, and append it to the running list below so it gets reused.

**In use** (224 tags, alphabetical):

`acpi` · `adblocking` · `aide` · `anonymity` · `app-list` · `apparmor` · `arch`
`arch-linux` · `aria2` · `ascii` · `ast` · `audit` · `auditd` · `aur`
`authentication` · `automation` · `backdoor` · `backup` · `bash` · `benchmarking`
`boot` · `brasil` · `btrfs` · `c` · `cgroups` · `characters` · `cheatsheet` · `ci`
`clamav` · `cli` · `client` · `codigos-eleitorais` · `compose` · `containers`
`conventions` · `creative-tools` · `css` · `curated` · `data-modeling`
`data-oriented` · `data-structures` · `dataview` · `debug` · `debugging` · `desktop`
`devcontainer` · `development` · `devops` · `diagnostics` · `discord` · `disk-management`
`dm-crypt` · `dns` · `dns-over-https` · `dnscrypt` · `docker` · `documentation`
`dotfiles` · `downloads` · `eBPF` · `eleicoes-2026` · `eleitoral` · `email`
`encoding` · `encryption` · `example` · `expect` · `file-integrity` · `filesystem`
`filtering` · `firewall` · `firmware` · `flathub` · `flatpak` · `forensics` · `foss`
`fwupd` · `gdb` · `git` · `guide` · `hardening` · `hardware` · `headers`
`hibernation` · `hids` · `himalaya` · `index` · `initramfs` · `iteration`
`javascript` · `job-control` · `json-like` · `kernel` · `kernel-modules`
`keyboard-shortcuts` · `kubernetes` · `kvm` · `legislacao` · `lexer` · `libvirt`
`links` · `linux` · `logging` · `luks` · `lvfs` · `lvm` · `lynis`
`mac-address-randomization` · `maintenance` · `malware-scanning`
`mandatory-access-control` · `markdown` · `matcha` · `mediawiki` · `memory` · `meta`
`metasearch` · `microphone` · `mirrors` · `moc` · `modules` · `monitoring` · `mosh`
`multi-machine` · `neomutt` · `networking` · `networkmanager` · `nftables` · `niri`
`noctalia` · `norte-pioneiro` · `obsidian` · `office` · `oom` · `ownership`
`packages` · `pacman` · `pam` · `panorama-politico` · `parana` · `paranavai`
`parser` · `patches` · `performance` · `permissions` · `pesquisa`
`physical-security` · `plugins` · `podlet` · `podman` · `privacy` · `productivity`
`profiling` · `project` · `project-structure` · `provisioning` · `qemu` · `quadlet`
`query-language` · `readline` · `recommendations` · `recursive-descent`
`reference` · `remote-desktop` · `resource-limits` · `rootkit` · `runbook` · `rust`
`sandboxing` · `schema` · `searxng` · `secure-boot` · `security` · `self-audit`
`self-healing` · `self-hosting` · `services` · `setup` · `shell` · `signals`
`software` · `speedofsound` · `spi-flash` · `ssh` · `storage` · `stow` · `strings`
`sudo` · `supply-chain` · `swap` · `sysctl` · `systemd` · `table`
`task-management` · `template` · `terminal` · `testing` · `theming`
`threat-modeling` · `tmux` · `tokenization` · `tools` · `tor` · `tpm` · `tradeoffs`
`troubleshooting` · `tse-2026` · `tui` · `tutorial` · `uefi` · `ufw` · `unix`
`updates` · `usb` · `vesktop` · `virt-manager` · `virtualization` · `wallpaper`
`watchdog` · `wayland` · `wikimedia` · `workflow` · `zram` · `zsh`

**Format-flavoured tags** mirror the `type` vocabulary (`ref`-like) and are kept for
compatibility: `reference` · `runbook` · `guide` · `cheatsheet` · `moc` · `template` ·
`audit` · `self-audit` · `app-list` · `curated` · `troubleshooting`. For new notes prefer
the `type:` field over a format tag.

---

## 6. Naming and location

- Filenames are the note identity: `kebab-case.md`. Folders too: lowercase `kebab-case`.
- No dates, no `v2`, no `final`, no copy suffixes. Supersede by editing; set the old note to
  `status: archived` if it must be kept.
- **Topic folders, not format folders.** A folder is named for its subject; the note's format is
  the `type:` field, so there is no `tutorial/` or `runbooks/` directory.
- Distro-specific notes live in `arch-linux/`; distro-agnostic ones in `linux/`; cross-distro
  domains (`storage/`, `networking/`, `containers/`, `desktop/`, `email/`, `development/`,
  `reference/`) are top-level.
- Up to **three** levels deep (e.g. `arch-linux/hardening/<domain>/<note>.md`). Deeper than that
  and you are hiding a missing index note.
- Not notes: `templates/` (Obsidian Templates skeletons — excluded from search and queries),
  `scripts/` (shell and systemd attachments), `AGENTS.md` (agent config), `.obsidian/` (app
  config), `_clones/` and `__clones/` (upstream Git clones). All stay out of search, the graph,
  and every Dataview query.

---

## 7. Unresolved wikilinks are intentional

`related:` and body links to notes that do not exist yet are **topic placeholders** — they seed
the graph and mark what to write next. They are not broken links to fix. To find what is
missing, use the orphan query in [[Home]] or the graph view.

---

## 8. Obsidian requirements

- **`.obsidian/types.json`** — assigns every standard field an Obsidian type (the registry, §2.8)
  so the Properties panel renders date pickers, checkboxes and number fields, and Bases can query
  them. It is checked in; keep it in lockstep with the registry.
- **Bases** (core plugin, enabled) — the native way to query properties into tables, cards and
  views. Prefer a `.base` file over a Dataview block for new dashboards; it needs no community
  plugin. See `all-notes.base`.
- **Dataview** (community plugin) — powers the [[Home]] queries. It is **not currently
  installed**, so those blocks fall back to static text; install Dataview to switch them on, or
  migrate them to a Base. The queries document intent either way.
- **Tasks** (community plugin) — task management across notes; see [[Obsidian Tasks Plugin]] and
  [[Obsidian Tasks Cheatsheet]].
- **Templates** (core plugin) — points at `templates/`. That folder is in `userIgnoreFilters`
  (`.obsidian/app.json`) and excluded from every query, so skeleton frontmatter never pollutes a
  search result or a table.
- **Mermaid and MathJax** render natively — use ```` ```mermaid ```` diagrams and `$...$` /
  `$$...$$` math in data and dev notes. Both are Obsidian-only (§9).
- `cssclasses` (`nota-longa`, `wide-table`, `cheatsheet`, `index`, `reference`, `template`) are
  inert strings until a CSS snippet defines them.

---

## 9. Portability

| Feature | Portable? | Note |
|---|---|---|
| YAML frontmatter | yes | every SSG reads it; why the schema is plain |
| `[[wikilinks]]` | **no** | renders literally; Obsidian-only |
| `> [!warning]` callouts | **no** | renders as a plain blockquote |
| `- [ ]` task lists | yes | CommonMark |
| `\|` tables | yes | GFM |
| `==highlight==` | **no** | not used in this vault |
| `$...$` math | **no** | MathJax; convert to rendered images for export |
| ```mermaid fences | **no** | rendered by Obsidian; convert to static SVG for export |
| Dataview blocks | **no** | Obsidian-only; the query text stays readable |
| Bases (`.base`) | **no** | Obsidian-only |

GitHub-Wiki export is mechanical: `[[A|B]]` → `[B](A.md)`, `> [!type] Title` → `> **Title**`.
Keep that as a script, not a manual pass.

## 10. Dataview cookbook

Every note is reachable through these. Copy freely; always scope `FROM` with
`-"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian"`.

**Notes needing review, soonest first**

````dataview
TABLE WITHOUT ID file.link AS "Note", review_after AS "Due"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE review_after SORT review_after ASC
````

**Notes with open actions**

````dataview
TABLE WITHOUT ID file.link AS "Note", status, actions
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE status = "needs-action"
````

**Everything tagged with a topic**

````dataview
LIST FROM "#btrfs"
````

**Backlinks**

````dataview
LIST FROM [[Home]]
````

**Expired or expiring soon**

````dataview
TABLE WITHOUT ID file.link AS "Note", expires AS "Expires"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE expires AND expires <= date(today) + dur(14 days)
````

**Data-bearing notes** — anything with a stated sample size or dataset

````dataview
TABLE WITHOUT ID file.link AS "Note", methodology, sample_size AS "n", temporal_coverage AS "Covers", metrics
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE sample_size OR data_source
SORT sample_size DESC
````

**Developer & tooling notes**

````dataview
TABLE WITHOUT ID file.link AS "Note", runtime, entrypoint, deps, version
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE entrypoint OR deps OR runtime
SORT file.name ASC
````

**Hosts and their environment**

````dataview
TABLE WITHOUT ID file.link AS "Note", host, os, kernel, hardware
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE host
SORT host ASC
````

**Verified vs unverified**

````dataview
TABLE WITHOUT ID file.link AS "Note", verified, verification_method AS "Method"
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE confidence OR verified
SORT verified DESC
````

**Open findings and their fixes** (audits / diagnostics)

````dataview
TABLE WITHOUT ID file.link AS "Note", findings, actions
FROM -"_clones" -"__clones" -"templates" -"AGENTS.md" -".obsidian" WHERE findings
````

### Bases equivalent

Obsidian Bases (core) reads the same properties natively — no community plugin. `all-notes.base`
ships views for review queues, data notes, developer notes and host notes; filter with
`file.inFolder`, list columns with `order`, and group with `groupBy` — **an object with
`property` and `direction`**, never a bare property name:

```yaml
filters:
  and:
    - not:
        - file.inFolder("_clones")
    - not:
        - file.inFolder("__clones")
    - not:
        - file.inFolder("templates")
views:
  - type: table
    name: "By status"
    groupBy:
      property: note.status
      direction: ASC
    order:
      - file.name
      - type
      - updated
```

Property prefixes are `file.*` (file metadata), `note.*` (frontmatter), and `formula.*`; a bare
name is accepted for frontmatter but `note.status` is unambiguous. Prefer editing the shipped
`all-notes.base` over copying this snippet.

---

## 11. Extending the schema

The schema is meant to grow. Growth is a contract, not an improvisation: every step below keeps
the Properties panel, Bases and existing queries working.

**Add a field — four steps.**

1. Decide its profile (§2.2). If none fits, it is bespoke (§2.7) — go to step 4 only.
2. Add one row to the registry (§2.8): field, Obsidian type, profile, meaning.
3. Add the same type to `.obsidian/types.json`.
4. Add the commented field to `templates/note-template.md`, under its banner.

**Add a profile** — the same four steps for each field, plus: a §2.x table describing it, a row
in the §2.2 overview, and a cookbook query (§10) only if it earns one.

**Rename or retire a field** — update the registry, `.obsidian/types.json`, the template, and any
query that names it. Never reuse a retired name for a different meaning; queries in old notes'
history would silently change.

> [!warning] The one rule that makes profiles safe
> A field is either **core** (in the registry's core group), **profiled** (in the registry under a
> profile), or **bespoke** (last, under a banner). There is no fourth state. If you cannot say
> which one a field is, it is not ready to add.

---

## Sources

- [Obsidian Help — Properties](https://help.obsidian.md/Editing+and+formatting/Properties) — property types and the Properties panel.
- [Obsidian Help — Bases](https://help.obsidian.md/Bases) — native property queries; why bases come first.
- [Obsidian Dataview — Data annotation](https://blacksmithgu.github.io/obsidian-dataview/data-annotation/) — frontmatter and inline fields.
- [danielrosehill/Obsidian-Research-Vault-Template](https://github.com/danielrosehill/Obsidian-Research-Vault-Template) — per-type frontmatter and quoted wikilinks in frontmatter.
- [mbrannigan/obsidian-vault-template](https://github.com/mbrannigan/obsidian-vault-template) — engineer-oriented vault structure and plugin expectations.
- [grahamhelton.com — Human Memory Management and Obsidian V2](https://grahamhelton.com/blog/obsidian-v2) — consistency of frontmatter over field choice; Bases as views.

# cg-rs

Rust rewrite of the `cg.py` ChatGPT organizer. Same rules, same database, no
delete path: the only destructive-looking action is archiving, and archiving is
reversible.

**Status:** offline core (`ingest`, `plan`, `status`, `archive`, `unarchive`,
`organize`, `unorganize`, `move`) is implemented and tested. Live commands
(`sync`, `login`, `auth`) require a browser cookie and are under active
development; see `TODO.md`.

## Safety model

- No command deletes a conversation. The only destructive-looking action is
  `archive`, which is reversible via `unarchive`.
- Live writes are dry-run by default; `--yes` / `-f` is required to send anything.
- Offline commands never open a socket or touch the network.
- A chat from a custom GPT (`g-…`) is never refiled; only Projects
  (`g-p-…`) are valid destinations.
- Chats whose bodies were never fetched are never auto-archived.

## Build and test

```sh
cargo build --release
cargo test
```

The binary is `target/release/cg`. System SQLite is used (Arch has the headers);
nothing is vendored.

Quality gates:

```sh
just fmt      # cargo fmt
just lint     # clippy, all targets, warnings are errors
just test     # unit + integration
just audit    # cargo-audit (installed)
just deny     # cargo-deny licenses/advisories/sources
just check    # fmt-check + lint + test
```

MSRV is 1.88 (edition 2024 plus `zip` 9).

## Commands

### `cg ingest <source>`

Index an official ChatGPT export from a `.zip`, `.json`, or directory containing
`conversations*.json`. The index is stored in the SQLite database at
`~/.local/state/cg/cg.db`.

```sh
cg ingest /path/to/chatgpt-export.zip
cg ingest /path/to/export/directory
```

### `cg plan [--days N]`

Generate a plan report classifying all indexed conversations. Writes two files:

- `~/.local/state/cg/reports/plan-<timestamp>.md` — Markdown report for human
  reading, with sections for Keep, Review, Archive, and Review categories.
- `~/.local/state/cg/reports/plan-<timestamp>.tsv` — Tab-separated values report
  for filtering or further processing.

```sh
cg plan
cg plan --days 60     # use 60 days instead of default 120
```

### `cg status`

Show summary of what is indexed: total conversations, archived count, project
distribution, and database path.

```sh
cg status
```

### `cg archive [--run] [--list] [--stats] [--show <id>]`

Archive conversations marked as `Verdict::Archive` in the plan. This command
has multiple modes:

- **No argument** (default): Dry-run. Shows which conversations would be archived
  without making any changes. This is the safe default.
- `--run`: Actually archive the conversations. Requires `--yes` flag to confirm.
- `--list`: List archive candidates with their titles and IDs.
- `--stats`: Show statistics about archived conversations.
- `--show <id>`: Show details of a specific archived conversation by ID.

```sh
cg archive              # dry-run: show what would be archived
cg archive --run --yes  # actually archive the candidates
cg archive --list       # list archive candidates
cg archive --stats      # show archival statistics
cg archive --show abc123  # show details of conversation abc123
```

### `cg unarchive [--yes]`

Restore previously archived conversations. Reverses the `archive` command.

```sh
cg unarchive            # dry-run: show what would be restored
cg unarchive --yes      # actually restore the conversations
```

### `cg organize [--yes]`

Move conversations to Projects based on the classification. Dry-run by default.

```sh
cg organize             # dry-run: show what would be organized
cg organize --yes       # actually move conversations to projects
```

### `cg unorganize [--yes]`

Undo `organize`: move conversations back to their previous project. Reversible.

```sh
cg unorganize           # dry-run
cg unorganize --yes     # actually undo
```

### `cg move [--yes]`

Move conversations between Projects. Dry-run by default.

```sh
cg move --yes           # actually move conversations
```

### `cg login`

Save a browser session cookie for live API commands (`sync`, `organize`,
`archive`). The cookie is stored securely at `~/.local/state/cg/session` with
restricted file permissions (0600).

```sh
cg login
```

### `cg auth`

Test whether the saved session cookie is still valid.

```sh
cg auth
```

### `cg sync [--deep]`

Download conversation data from the ChatGPT API. With `--deep`, also fetches
asset labels and metadata.

```sh
cg sync
cg sync --deep
```

## Report format

The `cg plan` command generates two files side-by-side:

### Markdown report (`plan-<timestamp>.md`)

A human-readable document with:

- Summary statistics (total, keep, archive, review counts)
- Detailed conversation listings grouped by verdict
- Stale conversation detection (conversations older than N days)
- Archive candidacy information

### TSV report (`plan-<timestamp>.tsv`)

Tab-separated values with columns:

| Column | Meaning |
|---|---|
| `id` | Conversation UUID |
| `title` | Conversation title (fallback to first question) |
| `verdict` | `keep`, `review`, `archive`, `delete`, or `unknown` |
| `project` | Assigned project ID or empty |
| `turns` | Number of message turns |
| `chars` | Total character count |
| `stale` | Whether conversation exceeds the age limit |
| `age_days` | Age of conversation in days |

The TSV format is designed to be compatible with the Python `cg.py` tool so
that users can switch between implementations without losing data.

## Layout

| Path | Purpose |
|---|---|
| `~/.local/state/cg/cg.db` | SQLite index (compatible with `cg.py`) |
| `~/.local/state/cg/reports/` | plan Markdown and TSV reports |
| `~/.local/state/cg/session` | saved cookie (live commands, 0600 permissions) |
| `~/.cache/cg/` | conversation cache and debug log |

## Exit codes

- `0` — success
- `1` — ordinary failure (usage error, missing data, etc.)
- `2` — authentication or rate-limited
- `130` — interrupted (e.g., SIGINT during `--yes` confirmation)

## Relationship to the Python tool

`cg.py` and `cg_services.py` remain the reference until parity is proven. The
database schema and report shape are intentionally compatible, so the existing
index can be read as-is. The Rust implementation follows the same rules for
classification, verdicts, and archival behavior.
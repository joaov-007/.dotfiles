# cg-rs

Rust rewrite of the `cg.py` ChatGPT organizer. Same rules, same database, no
delete path: the only destructive-looking action is archiving, and archiving is
reversible.

**Status:** offline core (`ingest`, `plan`, `status`, `archive`, `unarchive`,
`organize`, `unorganize`, `move`, `export`) is implemented and tested. Live
commands (`sync`, `login`, `auth`) require a browser cookie; `login --browser`
reads it from a running browser profile. Automation (`daemon`, `services`,
`completions`, `log`) is implemented; see `TODO.md` for the remaining parity
work.

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

### Install

```sh
just install                      # ~/.local/bin/cg + bash completion
BIN_DIR=/usr/local/bin just install   # or anywhere else on PATH
just uninstall
```

`install` runs `cargo build --release --locked`, copies the binary, and writes
the bash completion to `$XDG_DATA_HOME/bash-completion/completions/cg`. zsh is
handled by the shell config once `cg` is on PATH: `30-completion.zsh` caches
`cg completions zsh` in `~/.cache/zsh/init/cg.zsh` and refreshes it whenever the
binary is newer. fish, if installed, takes
`cg completions fish > ~/.config/fish/completions/cg.fish`.

`cargo install --path . --locked --force` also works, but it writes to
`~/.cargo/bin`, which comes later in this machine's PATH; a stale copy there is
shadowed by `~/.local/bin/cg`.

Quality gates:

```sh
just fmt           # cargo fmt
just lint          # clippy, all targets, warnings are errors
just test          # unit + integration, debug
just test-release  # same tests with optimizations
just overflow      # optimized build with overflow-checks + debug assertions
just miri          # optional UB checks (nightly + miri)
just audit         # cargo-audit (installed)
just deny          # cargo-deny licenses/advisories/sources
just qa            # everything above except miri
just check         # fmt-check + lint + test
```

`tests/robustness.rs` is the hostile-input suite: deterministic pseudo-random
strings/JSON through every parser, oversized cookies, deeply nested JSON,
garbage SQLite/ZIP files, and Unicode truncation. A failure there means a bad
file or a malicious export can panic the tool, so it runs in `just test`.

Memory and resource checks are covered by tests rather than a GC: browser
cookie snapshots must delete their 0600 files on success and failure, the run
lock is reentrant and released on drop, and journals tolerate a truncated last
line. Rust forbids `unsafe` in this crate, so buffer overflows are compile-time
bugs; `just overflow` additionally keeps arithmetic bounds checks on in an
optimized build.

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
`archive`). The cookie goes to the OS credential store by default:

| Platform | Store |
|---|---|
| Linux/BSD | Secret Service — GNOME Keyring, KWallet (`ksecretd`), KeePassXC |
| Windows | Credential Manager |
| macOS | Keychain |

```sh
cg login
```

To reuse the session of a browser that is already logged in, let cg find it:

```sh
cg login --browser              # scan profiles, running browsers first
cg login --store ~/.config/chromium/Default/Network/Cookies
```

On Linux, `--browser` looks at the profile of every running Chromium-family or
Firefox process (including a non-default `--user-data-dir` or `--profile`),
then at the conventional profile paths. Chromium keeps recent writes in `Cookies-wal` while
the browser is running, so cg copies the database and its sidecars into a 0600
temporary file and reads that copy; the browser's own locks never block it.

Headless machines, containers and locked keyrings have no usable secret
service. There the cookie is written to `~/.local/state/cg/session` with mode
0600 instead (a warning names the reason). Force either backend explicitly when
needed:

```sh
cg login --no-keyring        # always the 0600 file (drops an older keyring copy)
CG_KEYRING=0 cg login        # same, via environment
cg login --save ./session    # explicit path, still mode 0600
```

The legacy file is erased after a successful keyring write and on the next
`cg logout`, so a plaintext copy does not linger.

### `cg auth`

Test whether the saved session cookie is still valid. It reads the keyring
first, then the legacy file.

```sh
cg auth
```

### `cg logout`

Remove the session from the keyring and from disk.

```sh
cg logout
```

### `cg sync [--deep]`

Download conversation data from the ChatGPT API. With `--deep`, also fetches
asset labels and metadata.

```sh
cg sync
cg sync --deep
```

### `cg daemon [--once] [--cycles N]`

Run `sync` then `organize` on a loop, in the foreground. Each cycle takes the
same reentrant run lock as every write command, so a manual `cg organize --yes`
and the daemon never interleave. A failed or deferred sync skips the organize
step instead of moving stale data.

```sh
cg daemon                    # dry-run organize, random pause 5-10 min
cg daemon --yes              # apply organize
cg daemon --once --yes       # one cycle, for cron/systemd timers
cg daemon --cycles 3         # three cycles, then exit
cg daemon --no-deep          # list only, do not fetch bodies
```

Every run writes `reports/daemon-<timestamp>.jsonl` with one `start` line, one
`cycle` line per cycle (job name, exit code, duration, skip reason), and one
`stop` line. SIGINT/SIGTERM stop the loop after the current job; a 429 waits
`--backoff` seconds (default 1800) before the next cycle.

### `cg services [--mode timer|daemon] <action>`

Generate `systemd --user` units for the daemon. Files carry a
`# Generated by cg services` marker; anything without it is never overwritten.

```sh
cg services                          # discover installed units, change nothing
cg services discover                 # same, explicit
cg services show                     # print the units that would be generated
cg services register --no-start      # write cg.service + cg.timer
cg services register --mode daemon --yes
cg services status
cg services logs -f
cg services unregister
```

With no action, `cg services` only reports the units it finds in the unit
directory (managed by cg or matching `--name`) plus their active/enabled state.
`register` also refuses to overwrite a unit it did not generate: it reports the
file and exits without changing anything unless `--force` is given.

`timer` mode runs `cg daemon --once` from a `cg.timer`; `daemon` mode keeps one
long-running process with `Restart=on-failure`. `--wait-min`/`--wait-max` are
seconds. `--unit-dir`, `--dry-run`, and `--force` exist for scripts and tests.

### `cg completions <bash|zsh|fish>`

```sh
cg completions bash > ~/.local/share/bash-completion/completions/cg
cg completions zsh  > ~/.zfunc/_cg
cg completions fish > ~/.config/fish/completions/cg.fish
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
| OS keyring `cg/session@chatgpt.com` | saved cookie (default) |
| `~/.local/state/cg/session` | fallback cookie file (0600, headless only) |
| `~/.cache/cg/` | conversation cache and debug log |

On Windows the same layout lives under `%LOCALAPPDATA%\cg` and
`%USERPROFILE%\Documents\ChatGPT`.

## Exit codes

- `0` — success
- `1` — ordinary failure (usage error, missing data, etc.)
- `2` — authentication or rate-limited
- `130` — interrupted (e.g., SIGINT during `--yes` confirmation)

## Relationship to the Python tool

The original `cg.py` and `cg_services.py` are no longer in the tree; they remain
readable in git history. The database schema and report shape are intentionally
compatible, so the existing index can be read as-is. The Rust implementation
follows the same rules for classification, verdicts, and archival behavior.
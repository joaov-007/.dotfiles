# cg-rs — rewrite plan

Small phases, each one shippable and testable. A box is only checked when the
code, the tests, and the docs agree.

Reference implementation: `../cg.py` (read-only until parity is proven).

## Rules

- No delete path. Archive is the only destructive-looking action and it is
  reversible.
- Dry-run by default for every live write. `--yes` is required to send anything.
- Offline commands never touch the network.
- Every bug fix gets a regression test before the fix.
- No `unwrap`/`expect` outside tests; no `todo!`/`unimplemented!` anywhere
  (`clippy` enforces both; `clippy.toml` allows panics only in tests).
- User-facing text stays in Portuguese to match the existing tool; code,
  comments, and tests are English.

## 0. Foundation

- [x] New crate at `scripts/chatgpt/cg-rs` with `lib` + thin `bin`.
- [x] Format, lint, and supply-chain gates: `rustfmt.toml`, clippy lints in
      `Cargo.toml`, `clippy.toml`, `deny.toml`, `justfile`.
- [x] `Error` type with stable exit codes and no panics on user input.
- [x] `Paths` (XDG state/cache, env overrides) with tests.
- [ ] File lock for write commands (reentrant inside one process).

## 1. Offline core

- [x] Export reader: `.zip`, `.json`, directory; reject foreign JSON with a
      clear message. ZIP member matching is strict, directory matching broad.
- [x] Parse only the active branch (`current_node` -> root), drop machine noise,
      keep user/assistant text and asset labels.
- [x] Conversation model with validated `ConversationId`, body hash, first
      question, title fallback.
- [x] SQLite index: schema, migrations from the Python DB, WAL, busy timeout,
      upsert that never erases fetched content, `VACUUM INTO` snapshots.
- [x] Classifier: accent folding, boundary-exact n-grams, weighted terms,
      runner-up margin.
- [x] Plan: buckets, duplicate detection (same body / same opening), stale
      section, `review` fallback.
- [x] Reports: Markdown + TSV, deterministic ordering.
- [x] `ingest`, `plan`, `status` commands.
- [x] Tests: parser fixtures, one classifier case per category, bucket table,
      duplicate rules, schema migration, ingest -> plan end-to-end, exit codes,
      idempotent re-ingest.
- [x] `cargo audit` clean (zip upgraded to 9 for RUSTSEC-2026-0367/68/69).

## 2. Safe live actions

- [ ] HTTP transport behind a trait: one request in flight, 429 backoff,
      `Retry-After` (seconds and HTTP date), no POST retry on 5xx.
- [ ] Cookie normalization: whole header, named lines, wrapped lines, bare
      chunks; 0600 session file; clear errors for half-copied tokens.
- [ ] Reentrant run lock (`fs2`) around every write command.
- [ ] `auth`, `login` (paste/file; browser keyring import is phase 4),
      `sync` (list + resumable deep), `projects`.
- [ ] Typed ids already in place; wire `organize`, `move`, `auto`,
      `archive run`, `unarchive`, `unorganize` with:
      JSONL journal, DB snapshot, confirmation from the PATCH echo, 404
      bookkeeping, 401/403/429 abort codes.
- [ ] Tests with a fake API: dry-run sends nothing, filtering, undo journals,
      custom-GPT protection, 404 marking, rate-limit abort.

## 3. Automation

- [ ] `export` to Markdown, folder per project, never overwrite hand-edited
      notes without `--overwrite`.
- [ ] `services` unit renderer + `systemctl --user` seam (timer and daemon).
- [ ] `daemon --once/--cycles`: sync then organize, bounded, journaled, signal
      aware, lock-aware.
- [ ] `completions` for bash/zsh/fish via `clap_complete`.
- [ ] `log` command over the local log file.

## 4. Parity and cleanup

- [ ] Side-by-side checklist against `cg --help` of the Python version.
- [ ] Import the existing `~/.local/state/cg/cg.db` and run `plan`; diff the
      counts against the Python report.
- [ ] Browser cookie harvest (Chromium/Firefox + libsecret) behind a feature or
      a separate small module; keep it optional.
- [ ] Decide whether `cg.py`/`cg_services.py` stay as reference or are removed.
- [ ] Packaging: install binary name `cg`, shell completion, migration note.

## Audit commands

```sh
just fmt        # cargo fmt
just lint       # clippy, all targets, warnings are errors
just test       # unit + integration
just audit      # cargo-audit (installed)
just deny       # cargo-deny licenses/advisories/sources
just check      # fmt + lint + test
```

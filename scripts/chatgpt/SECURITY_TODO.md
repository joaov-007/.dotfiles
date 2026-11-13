# cg-rs — security hardening TODO

Proposal for in-process sandboxing, credential hardening, and paranoid deployment
modes. An item is done only when code, tests, and docs agree. The existing
`cargo-audit`, `cargo-deny`, clippy, and hostile-input gates stay green.

## Scope

Assets:

- ChatGPT session cookie, Chromium/Firefox profile snapshots, and libsecret
  password material.
- Full conversation export and the local SQLite index.
- Account writes through `sync`, `organize`, `archive`, and `move`.

Untrusted inputs:

- Export archives (`.zip`, JSON), browser SQLite databases, API responses and
  headers.
- Paths and environment variables that choose files (`--store`,
  `--cookie-file`, `CG_*`, `--base-url`).

Out of scope initially: root, a compromised kernel, ptrace/debugger access, and
other same-uid processes. State that explicitly in the docs.

Constraints:

- `unsafe_code = "forbid"` in this crate. Any unsafe FFI lives in a small,
  audited target-specific dependency or behind a documented lint exception.
- Linux/Arch first. OpenBSD `pledge`/`unveil` and other platforms are opt-in
  backends, not assumptions.
- New defaults must not silently weaken current behaviour.

## 0. Decisions and public surface

- [ ] Decide the default mode: recommendation is `auto` for one release, then
  `strict` for offline commands.
- [ ] Add a global `--sandbox=off|auto|strict` flag and `CG_SANDBOX` env var.
- [ ] Define `off` as today's behaviour, `auto` as apply-what-the-kernel-supports
  with a warning on fallback, and `strict` as fail closed when a requested
  control is unavailable.
- [ ] Add `--offline` for commands that can run without a network, even if the
  command normally supports live mode.
- [ ] Add a `cg security` diagnostic command (kernel/Landlock/seccomp support,
  active policy, allowed paths, current warnings).
- [ ] Document the per-command access matrix: files read, files written,
  network, exec, keyring/D-Bus, browser profiles.

## 1. Shared sandbox primitives

- [ ] Add `src/security.rs` with `SandboxPolicy` and a single `apply` entry
  point, called from `app::run` after CLI parsing and path resolution but before
  command dispatch.
- [ ] Set `PR_SET_NO_NEW_PRIVS` before any seccomp filter.
- [ ] Add a Landlock filesystem ruleset: allowed read paths, allowed write
  paths, everything else denied.
- [ ] Add Landlock network rules where the ABI supports them (Linux 6.7+); keep
  destination-host filtering in the HTTP layer because Landlock only restricts
  bind/connect ports.
- [ ] Add a seccomp-BPF layer:
  - deny `socket`, `connect`, `bind`, `sendto`, `recvfrom` for offline commands;
  - deny `execve`/`execveat` unless a command explicitly needs a helper;
  - reject unknown architectures instead of guessing.
- [ ] Add resource limits: address space, file size, open files, CPU time, and
  process count. Make values configurable.
- [ ] Canonicalize every path before adding it to a ruleset; reject missing or
  unresolved input paths early.
- [ ] Make unsupported controls explicit: `auto` warns and continues, `strict`
  returns a usage/security error naming the missing kernel feature.
- [ ] Add unit tests for policy parsing, path allow-listing, and unsupported
  kernel fallback.

## 2. Offline profile

Commands: `ingest`, `plan`, `status`, `export`, report generation, offline
`archive list/show/stats`.

- [ ] Allow read access to the export source (file or directory), state DB,
  cache, reports, and the minimum system files SQLite/chrono need
  (`/etc/localtime`, locale files discovered during testing).
- [ ] Allow writes only under the state and cache directories, plus the export
  destination when `cg export` runs.
- [ ] Deny all network syscalls and child-process execution.
- [ ] Add zip/JSON resource guards in addition to kernel limits: maximum member
  count, maximum extracted bytes, maximum JSON nesting/size, and clear errors.
- [ ] Verify every offline command under `--sandbox=strict` on a supported
  kernel.
- [ ] Add a test that tries to open a disallowed path and a socket from inside
  the sandbox and expects denial, not a panic.

## 3. Live and network profile

- [ ] Restrict HTTP destinations to an allowlist instead of relying only on the
  `http`/`https` scheme check. Cover `chatgpt.com`, its subdomains, and the
  OpenAI endpoints actually used.
- [ ] Treat `--base-url` as a credential-exfiltration risk: allow loopback and
  custom hosts only through an explicit test/unsafe flag, and warn loudly in
  normal mode.
- [ ] Disable automatic redirects or re-validate the host after every redirect.
- [ ] Keep the response body cap and add tests for oversized/truncated bodies.
- [ ] Restrict live profiles to the API host and the keyring/D-Bus socket; do
  not grant browser-profile or export paths unless the command needs them.
- [ ] Separate `login --browser` into its own policy: read-only browser profile,
  write only the 0600 snapshot under the state directory, no API network.
- [ ] Add a test that a live command cannot read `~/.ssh` or an unrelated home
  directory while the sandbox is strict.

## 4. Credential handling

- [ ] Add zeroizing wrappers for cookies, Chromium passwords, and bearer tokens;
  prefer `zeroize`/`secrecy` over plain `String` where the value crosses a
  boundary.
- [ ] Redact `Cookie`, `Authorization`, and `Proxy-Authorization` from debug
  logs and error messages; add a regression test with a fake secret.
- [ ] Open session and snapshot files with `O_NOFOLLOW`, create them with
  `create_new`, and force mode 0600; make the state directory 0700.
- [ ] Verify the snapshot path cannot escape the state directory through a
  symlink or hardlink swap.
- [ ] In strict mode, require the OS keyring unless `--no-keyring` was passed
  explicitly; never fall back silently.
- [ ] Document that `CG_COOKIE`, `CG_OSCRYPT_PASSWORD`, and `--cookie` expose
  secrets through the process environment/argv, and prefer `cg login`.
- [ ] Wipe temporary browser snapshots on every failure path; keep the existing
  drop guard and test it.

## 5. Subprocess isolation for untrusted parsers

- [ ] Add a small internal parser binary (or hidden subcommand) that reads one
  export and emits normalized records over a pipe.
- [ ] Apply the offline strict profile to the child: read-only input, no state
  writes, no network, no exec, minimal environment, no cookies.
- [ ] Stream or batch records so a large export does not require the whole
  parsed result in memory in the parent.
- [ ] Keep the parent's SQLite writes outside the untrusted parser.
- [ ] Test malformed ZIP/JSON, zip bombs, deeply nested JSON, truncated input,
  and a child killed by a resource limit.

## 6. Paranoid deployment modes

- [ ] `cg --sandbox=strict <offline command>`: primary documented mode.
- [ ] `cg --sandbox=strict --no-network ...` for machines where even DNS is
  considered a leak.
- [ ] Update `cg services` unit generation with systemd hardening:
  - `NoNewPrivileges=yes`
  - `PrivateTmp=yes`
  - `ProtectSystem=strict`
  - `ProtectHome=read-only`
  - `ReadWritePaths=%S/cg %C/cg`
  - `CapabilityBoundingSet=`
  - `RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6`
  - `SystemCallFilter=@system-service`
  - `SystemCallArchitectures=native`
  - `LockPersonality=yes`
  - `MemoryDenyWriteExecute=yes`
  - `RestrictRealtime=yes`
  - `RestrictSUIDSGID=yes`
  - `UMask=0077`
- [ ] Provide `bwrap` recipes for offline ingest and live sync. Bind only the
  input, state, and cache paths; use `--unshare-all`, `--die-with-parent`, and
  `--new-session`.
- [ ] Document a `systemd-run --user --scope` transient-sandbox example.
- [ ] Mention `firejail` as an alternative, not the default, and note its
  setuid/namespace trade-offs.
- [ ] Add an OpenBSD backend using `pledge`/`unveil` per command, compiled with
  `#[cfg(target_os = "openbsd")]`; keep the unsafe call in a dependency or a
  small documented module.
- [ ] Add a short “which mode should I use?” table to the docs.

## 7. Diagnostics and documentation

- [ ] `cg security` prints: kernel release, Landlock ABI, seccomp availability,
  active policy, allowed read/write paths, network state, and fallback warnings.
- [ ] Update `README.md` safety model with the sandbox modes and their limits.
- [ ] Add `docs/security.md` with the threat model, per-command matrix, bwrap and
  systemd examples, and known gaps.
- [ ] Extend `cg --help` `after_help` with one line about `--sandbox=strict`.
- [ ] Record in `TODO.md` that security hardening is tracked separately.

## 8. Tests and CI

- [ ] Unit-test `SandboxPolicy` selection and all CLI/env parsing.
- [ ] Integration-test offline commands under `strict` in a temporary root.
- [ ] Integration-test denial of a disallowed path and a socket.
- [ ] Make kernel-dependent tests skip with a clear message, not fail, when
  Landlock/seccomp is unavailable.
- [ ] Add a `just security` target that runs the sandbox tests on Linux.
- [ ] Keep `just qa`; add `cargo audit` and `cargo deny check` to CI when a CI
  workflow is added.
- [ ] Optional: `cargo-fuzz` targets for `parse_values`, `parse_conversation`,
  cookie parsing, and Chromium blob decryption.

## 9. Rollout

- [ ] Phase 1: `security` module, `--sandbox` flag, `cg security`, offline
  no-network profile, tests.
- [ ] Phase 2: live host allowlist, redirect policy, credential zeroizing and
  redaction, safe file creation.
- [ ] Phase 3: subprocess parser isolation.
- [ ] Phase 4: hardened systemd units, bwrap recipes, OpenBSD pledge/unveil.
- [ ] Phase 5: flip the recommended default for offline commands to `strict`
  after one release of `auto` with no regressions.

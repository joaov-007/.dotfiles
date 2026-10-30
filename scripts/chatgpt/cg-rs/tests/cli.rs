//! End-to-end tests: run the real binary against a temporary state directory.
//!
//! These cover the promises the CLI makes: offline commands never need a
//! cookie, ingest is idempotent, plan writes both reports, and failures use the
//! documented exit codes.
//!
//! # Test Organization
//!
//! Tests are grouped by functionality:
//! - `ingest` - test the ingest command and report generation
//! - `plan` - test the plan command behavior
//! - `status` - test the status command behavior
//! - `error_conditions` - test error exit codes and rejection of invalid input

// Test binaries panic on setup failures by design; production code does not.
#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::path::PathBuf;
use std::process::Output;

use serde_json::{Value, json};

/// A throwaway `$HOME` plus state/cache/export directories.
struct Sandbox {
    dir: tempfile::TempDir,
}

impl Sandbox {
    fn new() -> Self {
        Self {
            dir: tempfile::tempdir().expect("tempdir"),
        }
    }

    fn root(&self) -> &std::path::Path {
        self.dir.path()
    }

    fn state(&self) -> PathBuf {
        self.root().join("state")
    }

    fn cache(&self) -> PathBuf {
        self.root().join("cache")
    }

    fn export_dir(&self) -> PathBuf {
        self.root().join("export")
    }

    fn run(&self, args: &[&str]) -> Output {
        let mut command = std::process::Command::new(env!("CARGO_BIN_EXE_cg"));
        command
            .args(args)
            .env("HOME", self.root())
            .env("CG_STATE_DIR", self.state())
            .env("XDG_CACHE_HOME", self.cache())
            .env("CG_EXPORT_DIR", self.export_dir())
            .env_remove("CG_DEBUG")
            .output()
            .expect("run cg")
    }
}

fn write_export(sandbox: &Sandbox) -> PathBuf {
    let path = sandbox.root().join("conversations.json");
    let conversations = vec![
        conversation(
            "aaaaaaaa-0001",
            "Pacman and systemd",
            &long_body(),
            1_700_000_000.0,
        ),
        // Same body, later date: the second copy must be archived.
        conversation(
            "aaaaaaaa-0002",
            "Pacman and systemd",
            &long_body(),
            1_700_100_000.0,
        ),
        one_shot("aaaaaaaa-0003", "quick question", 1_700_200_000.0),
    ];
    let value = Value::Array(conversations);
    std::fs::write(&path, serde_json::to_vec(&value).expect("json")).expect("write");
    path
}

fn long_body() -> String {
    "pacman systemd arch linux update ".repeat(20)
}

fn node(id: &str, parent: Option<&str>, role: &str, text: &str, children: &[&str]) -> Value {
    json!({
        "id": id,
        "parent": parent,
        "children": children,
        "message": {
            "author": { "role": role },
            "content": { "content_type": "text", "parts": [text] },
            "create_time": 100.0
        }
    })
}

fn conversation(id: &str, title: &str, user_text: &str, created: f64) -> Value {
    json!({
        "id": id,
        "title": title,
        "create_time": created,
        "mapping": {
            "u1": node("u1", None, "user", user_text, &["a1"]),
            "a1": node("a1", Some("u1"), "assistant", "Sure.", &["u2"]),
            "u2": node("a2", Some("u1"), "user", "and then?", &["a2"]),
            "a2": node("a2", Some("u2"), "assistant", "Done.", &[]),
        },
        "current_node": "a2"
    })
}

/// One short question, one answer: the classic throwaway chat.
fn one_shot(id: &str, title: &str, created: f64) -> Value {
    json!({
        "id": id,
        "title": title,
        "create_time": created,
        "mapping": {
            "u1": node("u1", None, "user", "quick", &["a1"]),
            "a1": node("a1", Some("u1"), "assistant", "ok", &[]),
        },
        "current_node": "a1"
    })
}

fn stdout(output: &Output) -> String {
    String::from_utf8_lossy(&output.stdout).into_owned()
}

fn stderr(output: &Output) -> String {
    String::from_utf8_lossy(&output.stderr).into_owned()
}

fn assert_success(output: &Output) {
    assert!(
        output.status.success(),
        "command failed: status={:?}\nstdout:\n{}\nstderr:\n{}",
        output.status.code(),
        stdout(output),
        stderr(output)
    );
}

// ---------------------------------------------------------------------------
// Ingest tests
// ---------------------------------------------------------------------------

#[test]
fn ingest_is_idempotent_and_plan_writes_both_reports() {
    let sandbox = Sandbox::new();
    let export = write_export(&sandbox);
    let export = export.to_str().expect("utf-8 path");

    let first = sandbox.run(&["ingest", export]);
    assert_success(&first);
    let text = stdout(&first);
    assert!(text.contains("lidas     : 3"), "{text}");
    assert!(text.contains("novas     : 3"), "{text}");
    assert!(text.contains("atualizadas: 0"), "{text}");
    assert!(text.contains("índice    : 3 conversas"), "{text}");

    let second = sandbox.run(&["ingest", export]);
    assert_success(&second);
    let text = stdout(&second);
    assert!(text.contains("novas     : 0"), "{text}");
    assert!(text.contains("atualizadas: 3"), "{text}");
    assert!(text.contains("índice    : 3 conversas"), "{text}");

    let plan = sandbox.run(&["plan"]);
    assert_success(&plan);
    let text = stdout(&plan);
    assert!(text.contains("conversas  : 3"), "{text}");
    assert!(text.contains("manter     : 1"), "{text}");
    assert!(text.contains("arquivar   : 2"), "{text}");
    assert!(text.contains("nada foi alterado no site"), "{text}");

    let reports = sandbox.state().join("reports");
    let mut markdown = Vec::new();
    let mut tsv = Vec::new();
    for entry in std::fs::read_dir(&reports).expect("reports dir") {
        let path = entry.expect("entry").path();
        match path.extension().and_then(|ext| ext.to_str()) {
            Some("md") => markdown.push(path),
            Some("tsv") => tsv.push(path),
            _ => {}
        }
    }
    assert_eq!(markdown.len(), 1, "one markdown report");
    assert_eq!(tsv.len(), 1, "one tsv report");

    let table = std::fs::read_to_string(&tsv[0]).expect("tsv");
    let lines = table.lines().collect::<Vec<_>>();
    assert_eq!(lines.len(), 4, "header plus three conversations");
    assert_eq!(
        lines[0],
        "project\tverdict\tturns\tuser_chars\tcreated\ttitle\turl"
    );
    assert_eq!(
        lines
            .iter()
            .filter(|line| line.contains("\tkeep\t"))
            .count(),
        1
    );
    assert_eq!(
        lines
            .iter()
            .filter(|line| line.contains("\tarchive\t"))
            .count(),
        2
    );

    let plan_text = std::fs::read_to_string(&markdown[0]).expect("markdown");
    assert!(plan_text.contains("# ChatGPT — plano de organização"));
    assert!(plan_text.contains("## 2. Arquivar — 2"));
    assert!(plan_text.contains("mesma conversa"));

    let status = sandbox.run(&["status"]);
    assert_success(&status);
    let text = stdout(&status);
    assert!(text.contains("índice : 3 conversas"), "{text}");
    assert!(text.contains("último export: conversations.json"), "{text}");
}

// ---------------------------------------------------------------------------
// Plan error tests
// ---------------------------------------------------------------------------

#[test]
fn empty_index_fails_with_ordinary_exit_code() {
    let sandbox = Sandbox::new();
    let output = sandbox.run(&["plan"]);
    assert_eq!(output.status.code(), Some(1));
    let stderr_text = stderr(&output);
    assert!(stderr_text.contains("índice vazio"));
    assert!(!sandbox.state().join("reports").exists());
}

// ---------------------------------------------------------------------------
// Error condition tests
// ---------------------------------------------------------------------------

#[test]
fn missing_export_is_a_usage_error() {
    let sandbox = Sandbox::new();
    let missing = sandbox.root().join("nope.zip");
    let output = sandbox.run(&["ingest", missing.to_str().expect("path")]);
    assert_eq!(output.status.code(), Some(2));
    let stderr_text = stderr(&output);
    assert!(stderr_text.contains("não encontrado"));
}

#[test]
fn foreign_json_is_rejected_without_creating_state() {
    let sandbox = Sandbox::new();
    let path = sandbox.root().join("conversations.json");
    std::fs::write(&path, br#"{"hello":"world"}"#).expect("write");
    let output = sandbox.run(&["ingest", path.to_str().expect("path")]);
    assert_eq!(output.status.code(), Some(2));
    let stderr_text = stderr(&output);
    assert!(stderr_text.contains("não parece um export do ChatGPT"));
}

// ---------------------------------------------------------------------------
// Status tests
// ---------------------------------------------------------------------------

#[test]
fn status_works_on_a_fresh_install() {
    let sandbox = Sandbox::new();
    let output = sandbox.run(&["status"]);
    assert_success(&output);
    let text = stdout(&output);
    assert!(text.contains("índice : 0 conversas"), "{text}");
    assert!(text.contains("banco  :"), "{text}");
    assert!(text.contains("log    :"), "{text}");
}

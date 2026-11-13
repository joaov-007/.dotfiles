//! QA robustness tests: hostile input returns an error, never a panic.
//!
//! Rust rules out most memory bugs, but parsers still meet truncated files,
//! huge strings, invalid UTF-8, deeply nested JSON, and random bytes. These
//! tests run the public entry points over deterministic pseudo-random input so
//! a regression fails the normal `cargo test`, not a user's machine.

#![allow(clippy::expect_used, clippy::unwrap_used)]

use std::path::Path;

use cg::auth::build_cookie;
use cg::export::load_export;
use cg::http::validate_url;
use cg::journal;
use cg::model::{ConversationId, ProjectId, parse_conversation};
use cg::store::Index;
use cg::text::{slugify, table_cell, truncate_chars};
use serde_json::{Value, json};

/// Fixed seed: a failure is reproducible with `cargo test robustness`.
fn rng() -> fastrand::Rng {
    fastrand::Rng::with_seed(0x00C0_FFEE)
}

fn random_text(rng: &mut fastrand::Rng, max: usize) -> String {
    let len = rng.usize(0..=max);
    (0..len).map(|_| char::from(rng.u8(..=255))).collect()
}

fn random_value(rng: &mut fastrand::Rng, depth: u8) -> Value {
    if depth == 0 {
        return match rng.u8(..=3) {
            0 => Value::Null,
            1 => Value::Bool(rng.bool()),
            2 => json!(rng.i64(..)),
            _ => Value::String(random_text(rng, 32)),
        };
    }
    match rng.u8(..=4) {
        0 => Value::Array(
            (0..rng.usize(0..=3))
                .map(|_| random_value(rng, depth - 1))
                .collect(),
        ),
        1 => {
            let mut map = serde_json::Map::new();
            for _ in 0..rng.usize(0..=3) {
                map.insert(random_text(rng, 8), random_value(rng, depth - 1));
            }
            Value::Object(map)
        }
        _ => random_value(rng, 0),
    }
}

#[test]
fn random_text_never_panics_the_parsers() {
    let mut rng = rng();
    for _ in 0..2_000 {
        let text = random_text(&mut rng, 512);
        let _ = build_cookie(&text);
        let _ = validate_url(&text);
        let _ = ConversationId::parse(&text);
        let _ = ProjectId::parse(&text);
        let _ = journal::parse(&text);
        let _ = slugify(&text, rng.usize(0..=64));
        let _ = table_cell(&text, rng.usize(0..=64));
    }
}

#[test]
fn random_json_never_panics_the_conversation_parser() {
    let mut rng = rng();
    for _ in 0..500 {
        let value = random_value(&mut rng, 4);
        let _ = parse_conversation(&value);
    }

    // The shapes a real broken export produces, including wrong types.
    for value in [
        json!(null),
        json!([]),
        json!({}),
        json!({"id": 1, "mapping": "no"}),
        json!({"id": "aaaaaaaa-1", "mapping": {"a": null}, "current_node": "a"}),
        json!({"id": "aaaaaaaa-1", "mapping": {"a": {"message": []}}, "current_node": "a"}),
    ] {
        let _ = parse_conversation(&value);
    }
}

#[test]
fn truncation_never_splits_a_character() {
    let alphabet = ['a', 'é', '中', '🦀', '\u{301}', '\n'];
    let mut rng = rng();
    for limit in 0..20 {
        for _ in 0..100 {
            let text: String = (0..rng.usize(0..=80))
                .map(|_| alphabet[rng.usize(..alphabet.len())])
                .collect();
            let cut = truncate_chars(&text, limit);
            assert!(cut.chars().count() <= limit);
            assert!(std::str::from_utf8(cut.as_bytes()).is_ok());
            assert!(cut.len() <= text.len());
        }
    }
}

#[test]
fn a_huge_cookie_is_rejected_before_it_is_copied() {
    let huge = format!("a={}", "b".repeat(20_000));
    let error = build_cookie(&huge).expect_err("oversized cookie");
    let text = error.to_string();
    assert!(text.contains("demasiado grande"), "{text}");
}

#[test]
fn deeply_nested_json_is_rejected_without_a_stack_overflow() {
    let depth = 10_000;
    let deep = format!("{}{}", "[".repeat(depth), "]".repeat(depth));
    assert!(serde_json::from_str::<Value>(&deep).is_err());
}

#[cfg(target_os = "linux")]
#[test]
fn opening_and_closing_the_index_does_not_leak_file_descriptors() {
    fn fd_count() -> usize {
        std::fs::read_dir("/proc/self/fd").map_or(0, |entries| entries.flatten().count())
    }

    let dir = tempfile::tempdir().expect("tempdir");
    let db = dir.path().join("cg.db");
    let before = fd_count();
    for _ in 0..200 {
        drop(Index::open(&db).expect("open index"));
    }
    let after = fd_count();
    // Other tests in this binary may hold a descriptor briefly; a real leak
    // would grow by ~200, not by a handful.
    assert!(
        after <= before + 32,
        "file descriptor leak: {before} -> {after}"
    );
}

#[test]
fn a_garbage_database_is_an_error_not_a_panic() {
    let dir = tempfile::tempdir().expect("tempdir");
    let db = dir.path().join("cg.db");
    std::fs::write(&db, b"this is not sqlite").expect("seed");
    assert!(Index::open(&db).is_err());
}

#[test]
fn invalid_utf8_in_an_export_is_a_clean_error() {
    let dir = tempfile::tempdir().expect("tempdir");
    let json = dir.path().join("conversations.json");
    std::fs::write(&json, b"{\"id\":\"\xff\xfe\"}").expect("seed");
    assert!(load_export(&json).is_err());
}

#[test]
fn a_garbage_zip_is_an_error_not_a_panic() {
    let dir = tempfile::tempdir().expect("tempdir");
    let zip = dir.path().join("export.zip");
    std::fs::write(&zip, b"PK\x03\x04 not really a zip").expect("seed");
    assert!(load_export(&zip).is_err());
}

#[test]
fn a_missing_export_path_is_a_clean_error() {
    let dir = tempfile::tempdir().expect("tempdir");
    let missing = dir.path().join("nope.zip");
    assert!(load_export(&missing).is_err());
    assert!(load_export(Path::new("")).is_err());
}

//! Raw conversation bodies kept on disk, exactly like the Python tool:
//! `~/.cache/cg/convs/<conv_id>.json`.
//!
//! The index stores metadata only. `cg sync --deep` writes the raw JSON here so
//! `cg export`, `cg plan` and a later `cg sync` can work without re-downloading.

use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::config::Paths;
use crate::error::Result;
use crate::model::ConversationId;
use crate::note::atomic_write;

/// Cache file for one conversation.
#[must_use]
pub fn path(paths: &Paths, id: &ConversationId) -> PathBuf {
    paths.conv_cache.join(format!("{id}.json"))
}

/// Read the cached body, or `None` when missing or unreadable.
#[must_use]
pub fn read(paths: &Paths, id: &ConversationId) -> Option<Value> {
    read_file(&path(paths, id))
}

fn read_file(path: &Path) -> Option<Value> {
    let bytes = std::fs::read(path).ok()?;
    serde_json::from_slice(&bytes).ok()
}

/// Persist one body atomically. A crash never leaves a half-written cache.
pub fn write(paths: &Paths, id: &ConversationId, raw: &Value) -> Result<()> {
    paths.ensure_cache()?;
    let bytes = serde_json::to_vec(raw)?;
    atomic_write(&path(paths, id), &bytes)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn paths() -> (tempfile::TempDir, Paths) {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        (dir, paths)
    }

    #[test]
    fn round_trips_one_body() {
        let (_dir, paths) = paths();
        let id = ConversationId::parse("aaaaaaaa-1111").expect("id");
        let raw = json!({ "id": "aaaaaaaa-1111", "title": "x" });

        assert!(read(&paths, &id).is_none());
        write(&paths, &id, &raw).expect("write");
        assert_eq!(read(&paths, &id), Some(raw));
    }

    #[test]
    fn corrupt_files_are_ignored() {
        let (_dir, paths) = paths();
        let id = ConversationId::parse("aaaaaaaa-1111").expect("id");
        std::fs::create_dir_all(&paths.conv_cache).expect("mkdir");
        std::fs::write(path(&paths, &id), b"{not json").expect("seed");
        assert!(read(&paths, &id).is_none());
    }
}

//! Append-only JSONL journals for every write run.
//!
//! The journal is the undo file: `cg unorganize --log` replays moves backwards
//! and `cg unarchive --log` restores exactly what one archive run touched. Each
//! line is flushed immediately, so an interrupted run leaves a usable journal.
//!
//! Journal shape is compatible with the Python tool. Archive entries written by
//! Python have no `kind` field at all, so a missing kind means `archive`.

use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::path::{Path, PathBuf};

use chrono::{DateTime, Local};
use serde::Serialize;
use serde_json::Value;

use crate::error::Result;

/// One line of a journal.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
#[serde(tag = "kind", rename_all = "lowercase")]
pub enum Entry {
    Project {
        name: String,
        project_id: Option<String>,
        status: u16,
        ok: bool,
        at: String,
    },
    Move {
        conv_id: String,
        #[serde(rename = "from")]
        from: Option<String>,
        to: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        project: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        to_name: Option<String>,
        #[serde(skip_serializing_if = "Option::is_none")]
        from_name: Option<String>,
        status: u16,
        ok: bool,
        #[serde(default, skip_serializing_if = "is_false")]
        gone: bool,
        at: String,
    },
    Archive {
        conv_id: String,
        status: u16,
        ok: bool,
        at: String,
    },
}

#[allow(clippy::trivially_copy_pass_by_ref)]
fn is_false(value: &bool) -> bool {
    !*value
}

impl Entry {
    /// A project-creation record.
    #[must_use]
    pub fn project(name: &str, project_id: Option<&str>, status: u16, at: &str) -> Self {
        Self::Project {
            name: name.to_owned(),
            project_id: project_id.map(str::to_owned),
            status,
            ok: project_id.is_some(),
            at: at.to_owned(),
        }
    }

    /// A move record. `project` is the human name used by `unorganize` output.
    #[must_use]
    #[allow(clippy::too_many_arguments)]
    pub fn moved(
        conv_id: &str,
        from: Option<&str>,
        to: Option<&str>,
        project: Option<&str>,
        status: u16,
        ok: bool,
        gone: bool,
        at: &str,
    ) -> Self {
        Self::Move {
            conv_id: conv_id.to_owned(),
            from: from.map(str::to_owned),
            to: to.map(str::to_owned),
            project: project.map(str::to_owned),
            to_name: None,
            from_name: None,
            status,
            ok,
            gone,
            at: at.to_owned(),
        }
    }

    #[must_use]
    pub fn archived(conv_id: &str, status: u16, ok: bool, at: &str) -> Self {
        Self::Archive {
            conv_id: conv_id.to_owned(),
            status,
            ok,
            at: at.to_owned(),
        }
    }

    /// Parse one line, tolerating a missing `kind` (Python archive entries).
    #[must_use]
    pub fn from_value(value: &Value) -> Option<Self> {
        let kind = value
            .get("kind")
            .and_then(Value::as_str)
            .unwrap_or("archive");
        let text = |key: &str| {
            value
                .get(key)
                .and_then(Value::as_str)
                .map(str::to_owned)
                .filter(|value| !value.is_empty())
        };
        let status = value
            .get("status")
            .and_then(Value::as_u64)
            .and_then(|status| u16::try_from(status).ok())
            .unwrap_or(0);
        let ok = value.get("ok").and_then(Value::as_bool).unwrap_or(false);
        let at = text("at").unwrap_or_default();

        match kind {
            "project" => Some(Self::Project {
                name: text("name")?,
                project_id: text("project_id"),
                status,
                ok,
                at,
            }),
            "move" => Some(Self::Move {
                conv_id: text("conv_id")?,
                from: text("from"),
                to: text("to"),
                project: text("project"),
                to_name: text("to_name"),
                from_name: text("from_name"),
                status,
                ok,
                gone: value.get("gone").and_then(Value::as_bool).unwrap_or(false),
                at,
            }),
            "archive" => Some(Self::Archive {
                conv_id: text("conv_id")?,
                status,
                ok,
                at,
            }),
            _ => None,
        }
    }

    #[must_use]
    pub fn conv_id(&self) -> Option<&str> {
        match self {
            Self::Project { .. } => None,
            Self::Move { conv_id, .. } | Self::Archive { conv_id, .. } => Some(conv_id),
        }
    }
}

/// `YYYYmmdd-HHMMSS`, the stamp every report and snapshot uses.
#[must_use]
pub fn stamp(now: DateTime<Local>) -> String {
    now.format("%Y%m%d-%H%M%S").to_string()
}

/// `<reports>/<tag>-<stamp>.jsonl`
#[must_use]
pub fn path_for(reports: &Path, tag: &str, now: DateTime<Local>) -> PathBuf {
    reports.join(format!("{tag}-{}.jsonl", stamp(now)))
}

/// `<reports>/<tag>-<stamp>.db`
#[must_use]
pub fn snapshot_for(reports: &Path, tag: &str, now: DateTime<Local>) -> PathBuf {
    reports.join(format!("{tag}-{}.db", stamp(now)))
}

/// Open a journal for appending. The parent directory must exist.
pub fn create(path: &Path) -> Result<Journal> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let file = OpenOptions::new().create(true).append(true).open(path)?;
    Ok(Journal {
        writer: BufWriter::new(file),
        path: path.to_path_buf(),
    })
}

/// A journal being written. Every append is flushed before it returns.
#[derive(Debug)]
pub struct Journal {
    writer: BufWriter<File>,
    path: PathBuf,
}

impl Journal {
    pub fn append(&mut self, entry: &Entry) -> Result<()> {
        let line = serde_json::to_string(entry)?;
        self.writer.write_all(line.as_bytes())?;
        self.writer.write_all(b"\n")?;
        self.writer.flush()?;
        Ok(())
    }

    #[must_use]
    pub fn path(&self) -> &Path {
        &self.path
    }
}

/// Read a journal, skipping blank, malformed, or unknown lines.
///
/// A truncated last line is expected after a hard interrupt; it must not make
/// the whole undo file unusable.
pub fn read(path: &Path) -> Result<Vec<Entry>> {
    let text = std::fs::read_to_string(path)?;
    Ok(parse(&text))
}

/// Parse journal text. Exposed separately so tests need no temporary file.
#[must_use]
pub fn parse(text: &str) -> Vec<Entry> {
    text.lines()
        .filter(|line| !line.trim().is_empty())
        .filter_map(|line| serde_json::from_str::<Value>(line).ok())
        .filter_map(|value| Entry::from_value(&value))
        .collect()
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

    fn now() -> DateTime<Local> {
        DateTime::parse_from_rfc3339("2026-10-30T12:34:56-03:00")
            .expect("date")
            .with_timezone(&Local)
    }

    #[test]
    fn paths_use_the_expected_stamp() {
        let dir = Path::new("/tmp/reports");
        let now = now();
        assert_eq!(
            path_for(dir, "organize", now),
            PathBuf::from(format!("/tmp/reports/organize-{}.jsonl", stamp(now)))
        );
        assert_eq!(
            snapshot_for(dir, "organize-backup", now),
            PathBuf::from(format!("/tmp/reports/organize-backup-{}.db", stamp(now)))
        );
    }

    #[test]
    fn entries_round_trip_through_json() {
        let entries = [
            Entry::project("Linux", Some("g-p-111"), 201, "2026-10-30T12:00:00"),
            Entry::moved(
                "aaaaaaaa-1",
                None,
                Some("g-p-111"),
                Some("Linux"),
                200,
                true,
                false,
                "2026-10-30T12:00:01",
            ),
            Entry::archived("aaaaaaaa-2", 204, true, "2026-10-30T12:00:02"),
        ];
        let text = entries
            .iter()
            .map(|entry| serde_json::to_string(entry).expect("serialize"))
            .collect::<Vec<_>>()
            .join("\n");
        let parsed = parse(&text);
        assert_eq!(parsed, entries);
    }

    #[test]
    fn project_entries_carry_their_kind() {
        let value =
            serde_json::to_value(Entry::project("Linux", Some("g-p-1"), 201, "t")).expect("value");
        assert_eq!(value["kind"], "project");
        assert_eq!(value["ok"], true);
    }

    #[test]
    fn python_archive_entries_have_no_kind() {
        let text = r#"{"conv_id":"aaaaaaaa-1","status":200,"ok":true,"at":"2026-10-30T12:00:00"}"#;
        let entries = parse(text);
        assert_eq!(entries.len(), 1);
        assert!(matches!(entries[0], Entry::Archive { .. }));
        assert_eq!(entries[0].conv_id(), Some("aaaaaaaa-1"));
    }

    #[test]
    fn unknown_and_broken_lines_are_skipped() {
        let text = concat!(
            r#"{"kind":"mystery","conv_id":"x"}"#,
            "\n",
            "{\"kind\":\"move\",\"conv_id\":",
            "\n\n",
            r#"{"kind":"move","conv_id":"aaaaaaaa-1","status":200,"ok":true,"at":"t"}"#,
        );
        let entries = parse(text);
        assert_eq!(entries.len(), 1);
        assert!(matches!(entries[0], Entry::Move { .. }));
    }

    #[test]
    fn a_move_without_a_project_name_is_still_valid() {
        let entry = Entry::from_value(&json!({
            "kind": "move",
            "conv_id": "aaaaaaaa-1",
            "from": null,
            "to": null,
            "status": 200,
            "ok": true,
            "at": "t"
        }))
        .expect("entry");
        assert_eq!(entry.conv_id(), Some("aaaaaaaa-1"));
    }

    #[test]
    fn appends_are_visible_immediately() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("journal.jsonl");
        let mut journal = create(&path).expect("create");
        journal
            .append(&Entry::archived("aaaaaaaa-1", 200, true, "t"))
            .expect("append");
        let text = std::fs::read_to_string(&path).expect("read");
        assert_eq!(text.lines().count(), 1);
        journal
            .append(&Entry::archived("aaaaaaaa-2", 200, true, "t"))
            .expect("append");
        let entries = read(&path).expect("read journal");
        assert_eq!(entries.len(), 2);
    }
}

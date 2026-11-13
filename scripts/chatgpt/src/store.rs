//! SQLite index.
//!
//! The schema is compatible with the Python tool's `cg.db`, including the
//! columns added later (`has_content`, `user_turns`, `gone`, `project_id`), so
//! an existing index keeps working after the rewrite.

use std::collections::HashMap;
use std::path::Path;
use std::time::Duration;

use chrono::{DateTime, Local, NaiveDateTime, TimeZone};
use rusqlite::{Connection, OptionalExtension, params};

use crate::error::{Error, Result};
use crate::model::{Conversation, ConversationId};
use crate::text::collapse_ws;

const BUSY_TIMEOUT: Duration = Duration::from_secs(30);

/// One row of the index, with the fields commands actually read.
#[derive(Debug, Clone, PartialEq)]
pub struct StoredConversation {
    pub id: ConversationId,
    pub title: String,
    pub created_ts: Option<f64>,
    pub turns: i64,
    pub user_turns: i64,
    pub user_chars: i64,
    pub body_sha: String,
    pub first_user: String,
    pub sample: String,
    pub archived: bool,
    pub has_content: bool,
    pub gone: bool,
    pub project_id: Option<String>,
    pub source_file: Option<String>,
    pub indexed_at: String,
}

impl StoredConversation {
    /// `YYYY-MM-DD` in local time, or `?` when the export had no date.
    #[must_use]
    pub fn date(&self) -> String {
        self.created_at().map_or_else(
            || "?".to_owned(),
            |when| when.format("%Y-%m-%d").to_string(),
        )
    }

    #[must_use]
    pub fn created_at(&self) -> Option<DateTime<Local>> {
        let seconds = self.created_ts?;
        let whole = seconds.floor();
        #[allow(clippy::cast_possible_truncation)]
        let secs = whole as i64;
        #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
        let nanos = ((seconds - whole) * 1_000_000_000.0).round() as u32;
        Local.timestamp_opt(secs, nanos.min(999_999_999)).single()
    }

    #[must_use]
    pub fn link(&self) -> String {
        format!("https://chatgpt.com/c/{}", self.id)
    }
}

/// A handle to the local index.
#[derive(Debug)]
pub struct Index {
    conn: Connection,
}

impl Index {
    /// Open (and migrate) the index at `path`.
    pub fn open(path: &Path) -> Result<Self> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let conn = Connection::open(path)?;
        Self::from_connection(conn)
    }

    /// In-memory index for tests.
    pub fn open_in_memory() -> Result<Self> {
        Self::from_connection(Connection::open_in_memory()?)
    }

    fn from_connection(conn: Connection) -> Result<Self> {
        conn.busy_timeout(BUSY_TIMEOUT)?;
        // WAL lets `plan`/`status` read while a sync writes. An older process
        // may keep the file in `delete` mode for now; that still works.
        if !pragma_text(&conn, "journal_mode")?.eq_ignore_ascii_case("wal") {
            let _ = conn.pragma_update(None, "journal_mode", "WAL");
        }
        if pragma_text(&conn, "journal_mode")?.eq_ignore_ascii_case("wal") {
            conn.pragma_update(None, "synchronous", "NORMAL")?;
        }
        let index = Self { conn };
        index.migrate()?;
        Ok(index)
    }

    fn migrate(&self) -> Result<()> {
        self.conn.execute_batch(
            r"
            CREATE TABLE IF NOT EXISTS conversations (
                conv_id      TEXT PRIMARY KEY,
                title        TEXT NOT NULL,
                created_ts   REAL,
                turns        INTEGER NOT NULL,
                user_turns   INTEGER NOT NULL DEFAULT 0,
                user_chars   INTEGER NOT NULL,
                body_sha     TEXT NOT NULL,
                first_user   TEXT NOT NULL,
                sample       TEXT NOT NULL DEFAULT '',
                archived     INTEGER NOT NULL DEFAULT 0,
                has_content  INTEGER NOT NULL DEFAULT 0,
                gone         INTEGER NOT NULL DEFAULT 0,
                project_id   TEXT,
                source_file  TEXT,
                indexed_at   TEXT NOT NULL DEFAULT ''
            );
            CREATE TABLE IF NOT EXISTS sources (
                path    TEXT PRIMARY KEY,
                sha256  TEXT NOT NULL,
                size    INTEGER NOT NULL,
                seen_at TEXT NOT NULL,
                n_convs INTEGER NOT NULL DEFAULT 0
            );
            CREATE INDEX IF NOT EXISTS c_sha   ON conversations(body_sha);
            CREATE INDEX IF NOT EXISTS c_first ON conversations(first_user);
            ",
        )?;

        let mut added_has_content = false;
        for (column, definition) in [
            ("has_content", "INTEGER NOT NULL DEFAULT 0"),
            ("user_turns", "INTEGER NOT NULL DEFAULT 0"),
            ("project_id", "TEXT"),
            ("gone", "INTEGER NOT NULL DEFAULT 0"),
            ("sample", "TEXT NOT NULL DEFAULT ''"),
            ("source_file", "TEXT"),
            ("indexed_at", "TEXT NOT NULL DEFAULT ''"),
        ] {
            if !self.has_column("conversations", column)? {
                self.conn.execute(
                    &format!("ALTER TABLE conversations ADD COLUMN {column} {definition}"),
                    [],
                )?;
                added_has_content |= column == "has_content";
            }
        }
        if added_has_content {
            self.conn.execute(
                "UPDATE conversations SET has_content = 1 WHERE turns > 0",
                [],
            )?;
        }
        self.conn.execute_batch("PRAGMA user_version = 1;")?;
        Ok(())
    }

    fn has_column(&self, table: &str, column: &str) -> Result<bool> {
        let mut statement = self.conn.prepare(&format!("PRAGMA table_info({table})"))?;
        let mut rows = statement.query([])?;
        while let Some(row) = rows.next()? {
            if row.get::<_, String>(1)? == column {
                return Ok(true);
            }
        }
        Ok(false)
    }

    /// Upsert one conversation. Returns `true` when it was not indexed before.
    ///
    /// `fetched` marks that the message bodies came from a full fetch (the API
    /// list endpoint returns an empty mapping), so an empty chat can be told
    /// apart from an unfetched one.
    pub fn record(
        &self,
        conversation: &Conversation,
        source: &str,
        now: &str,
        fetched: Option<bool>,
    ) -> Result<bool> {
        let existed = self
            .conn
            .query_row(
                "SELECT 1 FROM conversations WHERE conv_id = ?1",
                params![conversation.id.as_str()],
                |_| Ok(()),
            )
            .optional()?
            .is_some();

        let has_content = fetched.unwrap_or_else(|| conversation.has_content());
        self.conn.execute(
            r"INSERT INTO conversations
                 (conv_id, title, created_ts, turns, user_turns, user_chars, body_sha,
                  first_user, sample, archived, has_content, project_id, source_file,
                  indexed_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)
               ON CONFLICT(conv_id) DO UPDATE SET
                 title=excluded.title, created_ts=excluded.created_ts,
                 -- the list endpoint carries no bodies: never let it erase
                 -- content that a deep fetch already stored.
                 turns      = CASE WHEN excluded.has_content = 1
                                   THEN excluded.turns      ELSE conversations.turns END,
                 user_turns = CASE WHEN excluded.has_content = 1
                                   THEN excluded.user_turns
                                   ELSE conversations.user_turns END,
                 user_chars = CASE WHEN excluded.has_content = 1
                                   THEN excluded.user_chars
                                   ELSE conversations.user_chars END,
                 body_sha   = CASE WHEN excluded.has_content = 1
                                   THEN excluded.body_sha   ELSE conversations.body_sha END,
                 first_user = CASE WHEN excluded.has_content = 1
                                   THEN excluded.first_user
                                   ELSE conversations.first_user END,
                 sample     = CASE WHEN excluded.has_content = 1
                                   THEN excluded.sample     ELSE conversations.sample END,
                 archived=excluded.archived,
                 -- membership changes on the website, so the freshest list wins
                 project_id=excluded.project_id,
                 has_content=MAX(excluded.has_content, conversations.has_content),
                 -- seeing it again means the server still has it: clear any 404
                 gone=0,
                 source_file=excluded.source_file, indexed_at=excluded.indexed_at",
            params![
                conversation.id.as_str(),
                conversation.title,
                conversation.created.map(epoch_seconds),
                i64::try_from(conversation.turns.len()).unwrap_or(i64::MAX),
                i64::try_from(conversation.user_turns()).unwrap_or(i64::MAX),
                i64::try_from(conversation.user_chars()).unwrap_or(i64::MAX),
                conversation.body_sha(),
                conversation.first_user(),
                conversation.sample(),
                i64::from(conversation.archived),
                i64::from(has_content),
                conversation.project_id,
                source,
                now,
            ],
        )?;
        Ok(!existed)
    }

    /// Record an export file for `status`.
    pub fn record_source(
        &self,
        path: &str,
        sha256: &str,
        size: u64,
        seen_at: &str,
        n_convs: usize,
    ) -> Result<()> {
        self.conn.execute(
            r"INSERT INTO sources (path, sha256, size, seen_at, n_convs) VALUES (?,?,?,?,?)
               ON CONFLICT(path) DO UPDATE SET sha256=excluded.sha256, size=excluded.size,
                 seen_at=excluded.seen_at, n_convs=excluded.n_convs",
            params![
                path,
                sha256,
                i64::try_from(size).unwrap_or(i64::MAX),
                seen_at,
                i64::try_from(n_convs).unwrap_or(i64::MAX),
            ],
        )?;
        Ok(())
    }

    /// Every row, oldest first.
    pub fn all(&self) -> Result<Vec<StoredConversation>> {
        self.query("SELECT * FROM conversations ORDER BY created_ts", [])
    }

    /// Every row the website still has.
    pub fn all_active(&self) -> Result<Vec<StoredConversation>> {
        self.query(
            "SELECT * FROM conversations WHERE gone = 0 ORDER BY created_ts",
            [],
        )
    }

    /// Chats whose bodies were never fetched, newest first.
    /// `limit == 0` means no limit; the second value is how many are left.
    pub fn missing_content(&self, limit: usize) -> Result<(Vec<ConversationId>, usize)> {
        let mut statement = self.conn.prepare(
            "SELECT conv_id FROM conversations WHERE has_content = 0 AND gone = 0 \
             ORDER BY created_ts DESC",
        )?;
        let ids = statement
            .query_map([], |row| row.get::<_, String>(0))?
            .filter_map(std::result::Result::ok)
            .filter_map(|raw| ConversationId::parse(&raw))
            .collect::<Vec<_>>();
        let total = ids.len();
        let take = if limit == 0 { total } else { limit.min(total) };
        Ok((ids.into_iter().take(take).collect(), total - take))
    }

    pub fn count(&self) -> Result<usize> {
        self.count_where("")
    }

    pub fn count_gone(&self) -> Result<usize> {
        self.count_where(" WHERE gone = 1")
    }

    fn count_where(&self, clause: &str) -> Result<usize> {
        let sql = format!("SELECT COUNT(*) FROM conversations{clause}");
        let count: i64 = self.conn.query_row(&sql, [], |row| row.get(0))?;
        Ok(usize::try_from(count).unwrap_or(0))
    }

    /// The most recent export in `sources`.
    pub fn latest_source(&self) -> Result<Option<SourceRow>> {
        self.conn
            .query_row(
                "SELECT path, seen_at, n_convs FROM sources ORDER BY seen_at DESC LIMIT 1",
                [],
                |row| {
                    Ok(SourceRow {
                        path: row.get(0)?,
                        seen_at: row.get(1)?,
                        conversations: row.get(2)?,
                    })
                },
            )
            .optional()
            .map_err(Error::from)
    }

    /// Mark a chat the server answered 404 for.
    pub fn mark_gone(&self, id: &ConversationId) -> Result<()> {
        self.conn.execute(
            "UPDATE conversations SET gone = 1 WHERE conv_id = ?1",
            params![id.as_str()],
        )?;
        Ok(())
    }

    pub fn set_archived(&self, id: &ConversationId, archived: bool) -> Result<()> {
        self.conn.execute(
            "UPDATE conversations SET archived = ?1 WHERE conv_id = ?2",
            params![i64::from(archived), id.as_str()],
        )?;
        Ok(())
    }

    pub fn set_project(&self, id: &ConversationId, project: Option<&str>) -> Result<()> {
        self.conn.execute(
            "UPDATE conversations SET project_id = ?1 WHERE conv_id = ?2",
            params![project, id.as_str()],
        )?;
        Ok(())
    }

    /// Ids of every chat the index believes is archived.
    pub fn archived_ids(&self) -> Result<Vec<ConversationId>> {
        let mut statement = self
            .conn
            .prepare("SELECT conv_id FROM conversations WHERE archived = 1 AND gone = 0")?;
        let ids = statement
            .query_map([], |row| row.get::<_, String>(0))?
            .filter_map(std::result::Result::ok)
            .filter_map(|raw| ConversationId::parse(&raw))
            .collect();
        Ok(ids)
    }

    /// Resolve an id prefix, newest first. Multiple rows mean "type more".
    pub fn find_prefix(&self, prefix: &str) -> Result<Vec<StoredConversation>> {
        let prefix = prefix.trim();
        if prefix.is_empty() {
            return Err(Error::usage("informe pelo menos um caractere do id"));
        }
        if !prefix
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
        {
            return Err(Error::usage(format!("id inválido: {prefix:?}")));
        }
        let pattern = format!(
            "{}%",
            prefix
                .replace('\\', "\\\\")
                .replace('%', "\\%")
                .replace('_', "\\_")
        );
        self.query(
            "SELECT * FROM conversations WHERE conv_id LIKE ?1 ESCAPE '\\' \
             ORDER BY created_ts DESC",
            params![pattern],
        )
    }

    /// Conversation counts per project id, for `cg projects`.
    pub fn project_counts(&self) -> Result<HashMap<String, i64>> {
        let mut statement = self.conn.prepare(
            "SELECT project_id, COUNT(*) FROM conversations \
             WHERE project_id IS NOT NULL AND gone = 0 GROUP BY project_id",
        )?;
        let mut counts = HashMap::new();
        let mut rows = statement.query([])?;
        while let Some(row) = rows.next()? {
            counts.insert(row.get(0)?, row.get(1)?);
        }
        Ok(counts)
    }

    pub fn loose_count(&self) -> Result<i64> {
        self.conn
            .query_row(
                "SELECT COUNT(*) FROM conversations WHERE project_id IS NULL AND gone = 0",
                [],
                |row| row.get(0),
            )
            .map_err(Error::from)
    }

    /// Minutes since the last ingest/sync, or `None` for an empty index.
    #[allow(clippy::cast_precision_loss)] // minute resolution, not a timestamp
    pub fn age_minutes(&self, now: DateTime<Local>) -> Result<Option<f64>> {
        let raw: Option<String> =
            self.conn
                .query_row("SELECT MAX(indexed_at) FROM conversations", [], |row| {
                    row.get(0)
                })?;
        let Some(raw) = raw.filter(|value| !value.is_empty()) else {
            return Ok(None);
        };
        let Ok(parsed) = NaiveDateTime::parse_from_str(&raw, "%Y-%m-%dT%H:%M:%S") else {
            return Ok(None);
        };
        Ok(Some(
            now.naive_local()
                .signed_duration_since(parsed)
                .num_seconds() as f64
                / 60.0,
        ))
    }

    /// Copy the index before a write run, so a bad batch can be rolled back.
    pub fn snapshot(&self, destination: &Path) -> Result<()> {
        if let Some(parent) = destination.parent() {
            std::fs::create_dir_all(parent)?;
        }
        if destination.exists() {
            return Err(Error::Invalid(format!(
                "o snapshot já existe: {}",
                destination.display()
            )));
        }
        self.conn.execute(
            "VACUUM INTO ?1",
            params![destination.to_string_lossy().as_ref()],
        )?;
        Ok(())
    }

    fn query<P: rusqlite::Params>(&self, sql: &str, params: P) -> Result<Vec<StoredConversation>> {
        let mut statement = self.conn.prepare(sql)?;
        let rows = statement.query_map(params, StoredConversation::from_row)?;
        let mut out = Vec::new();
        for row in rows {
            out.push(row?);
        }
        Ok(out)
    }
}

/// Last export recorded by `ingest`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SourceRow {
    pub path: String,
    pub seen_at: String,
    pub conversations: i64,
}

impl StoredConversation {
    fn from_row(row: &rusqlite::Row<'_>) -> rusqlite::Result<Self> {
        let id: String = row.get("conv_id")?;
        let id = ConversationId::parse(&id).ok_or_else(|| {
            rusqlite::Error::FromSqlConversionFailure(
                0,
                rusqlite::types::Type::Text,
                Box::new(std::io::Error::new(
                    std::io::ErrorKind::InvalidData,
                    "conv_id inválido no índice",
                )),
            )
        })?;
        Ok(Self {
            id,
            title: row.get("title")?,
            created_ts: row.get("created_ts")?,
            turns: row.get("turns")?,
            user_turns: row.get("user_turns")?,
            user_chars: row.get("user_chars")?,
            body_sha: row.get("body_sha")?,
            first_user: row.get("first_user")?,
            sample: row.get("sample")?,
            archived: row.get::<_, i64>("archived")? != 0,
            has_content: row.get::<_, i64>("has_content")? != 0,
            gone: row.get::<_, i64>("gone")? != 0,
            project_id: row.get("project_id")?,
            source_file: row.get("source_file")?,
            indexed_at: row.get("indexed_at")?,
        })
    }
}

/// Describe an index age without lying about an empty one.
#[must_use]
pub fn describe_age(minutes: Option<f64>) -> String {
    match minutes {
        None => "sem índice".to_owned(),
        Some(minutes) if minutes < 90.0 => format!("{minutes:.0} min atrás"),
        Some(minutes) => format!("{:.1} h atrás", minutes / 60.0),
    }
}

/// Collapse a title for one-line listings.
#[must_use]
pub fn one_line(text: &str, width: usize) -> String {
    let line = collapse_ws(text);
    if line.chars().count() <= width {
        line
    } else {
        format!(
            "{}…",
            line.chars()
                .take(width.saturating_sub(1))
                .collect::<String>()
        )
    }
}

fn pragma_text(conn: &Connection, pragma: &str) -> Result<String> {
    let value = conn.pragma_query_value(None, pragma, |row| row.get::<_, String>(0))?;
    Ok(value)
}

#[allow(clippy::cast_precision_loss)] // epoch seconds fit comfortably in f64
fn epoch_seconds(when: DateTime<Local>) -> f64 {
    when.timestamp() as f64
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;
    use crate::model::parse_conversation;

    fn conversation(id: &str, text: &str, archived: bool) -> Conversation {
        let raw = json!({
            "id": id,
            "title": "Title",
            "create_time": 1_700_000_000.0,
            "is_archived": archived,
            "gizmo_id": "g-p-project",
            "mapping": {
                "u": {
                    "id": "u", "parent": null, "children": [],
                    "message": {
                        "author": { "role": "user" },
                        "content": { "content_type": "text", "parts": [text] }
                    }
                }
            },
            "current_node": "u"
        });
        parse_conversation(&raw).expect("valid conversation")
    }

    #[test]
    fn first_insert_is_new_and_second_is_update() {
        let index = Index::open_in_memory().expect("index");
        let conv = conversation("abcdefgh-0001", "hello", false);
        assert!(
            index
                .record(&conv, "export.zip", "2026-01-01T10:00:00", None)
                .expect("insert")
        );
        assert!(
            !index
                .record(&conv, "export.zip", "2026-01-01T10:01:00", None)
                .expect("update")
        );
        assert_eq!(index.count().expect("count"), 1);
    }

    #[test]
    fn list_sync_never_erases_fetched_content() {
        let index = Index::open_in_memory().expect("index");
        let full = conversation("abcdefgh-0002", "the real body", false);
        index
            .record(&full, "api", "2026-01-01T10:00:00", Some(true))
            .expect("deep");
        let empty = conversation("abcdefgh-0002", "", false);
        index
            .record(&empty, "api", "2026-01-01T11:00:00", None)
            .expect("list");
        let row = index.all().expect("rows").remove(0);
        assert!(row.has_content);
        assert_eq!(row.turns, 1);
        assert_eq!(row.project_id.as_deref(), Some("g-p-project"));
    }

    #[test]
    fn seeing_a_row_again_clears_gone() {
        let index = Index::open_in_memory().expect("index");
        let conv = conversation("abcdefgh-0003", "hello", false);
        index
            .record(&conv, "api", "2026-01-01T10:00:00", None)
            .expect("insert");
        index.mark_gone(&conv.id).expect("gone");
        assert_eq!(index.count_gone().expect("count"), 1);
        index
            .record(&conv, "api", "2026-01-01T10:01:00", None)
            .expect("again");
        assert_eq!(index.count_gone().expect("count"), 0);
    }

    #[test]
    fn flags_and_membership_round_trip() {
        let index = Index::open_in_memory().expect("index");
        let conv = conversation("abcdefgh-0004", "hello", false);
        index
            .record(&conv, "api", "2026-01-01T10:00:00", None)
            .expect("insert");
        index.set_archived(&conv.id, true).expect("archive");
        index
            .set_project(&conv.id, Some("g-p-other"))
            .expect("project");
        let row = index.all().expect("rows").remove(0);
        assert!(row.archived);
        assert_eq!(row.project_id.as_deref(), Some("g-p-other"));
        assert_eq!(index.archived_ids().expect("ids"), vec![conv.id]);
    }

    #[test]
    fn prefix_lookup_refuses_ambiguous_and_unsafe_input() {
        let index = Index::open_in_memory().expect("index");
        for id in ["abcdefgh-0005", "abcdefgh-0006"] {
            let conv = conversation(id, "hello", false);
            index
                .record(&conv, "api", "2026-01-01T10:00:00", None)
                .expect("insert");
        }
        assert_eq!(index.find_prefix("abcdefgh").expect("matches").len(), 2);
        assert_eq!(index.find_prefix("abcdefgh-0005").expect("one").len(), 1);
        assert!(index.find_prefix("../etc").is_err());
    }

    #[test]
    fn missing_content_is_bounded_and_reports_the_remainder() {
        let index = Index::open_in_memory().expect("index");
        for n in 1..=3 {
            let conv = conversation(&format!("abcdefgh-00{n:02}"), "", false);
            index
                .record(&conv, "api", "2026-01-01T10:00:00", Some(false))
                .expect("insert");
        }
        let (batch, remaining) = index.missing_content(2).expect("missing");
        assert_eq!(batch.len(), 2);
        assert_eq!(remaining, 1);
    }

    #[test]
    fn old_python_schema_is_migrated() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("cg.db");
        {
            let conn = Connection::open(&path).expect("open");
            conn.execute_batch(
                r"CREATE TABLE conversations (
                    conv_id TEXT PRIMARY KEY, title TEXT NOT NULL, created_ts REAL,
                    turns INTEGER NOT NULL, user_chars INTEGER NOT NULL,
                    body_sha TEXT NOT NULL, first_user TEXT NOT NULL, sample TEXT NOT NULL,
                    archived INTEGER NOT NULL DEFAULT 0, source_file TEXT,
                    indexed_at TEXT NOT NULL);
                   INSERT INTO conversations VALUES
                    ('abcdefgh-0007','Old',1.0,2,10,'sha','first','sample',0,'old', '2026-01-01T00:00:00');",
            )
            .expect("old schema");
        }
        let index = Index::open(&path).expect("migrated");
        let row = index.all().expect("rows").remove(0);
        assert!(row.has_content);
        assert_eq!(row.user_turns, 0);
        assert!(!row.gone);
    }

    #[test]
    fn snapshot_copies_a_readable_database() {
        let index = Index::open_in_memory().expect("index");
        let conv = conversation("abcdefgh-0008", "hello", false);
        index
            .record(&conv, "api", "2026-01-01T10:00:00", None)
            .expect("insert");
        let dir = tempfile::tempdir().expect("tempdir");
        let copy = dir.path().join("backup.db");
        index.snapshot(&copy).expect("snapshot");
        let copy = Index::open(&copy).expect("open copy");
        assert_eq!(copy.count().expect("count"), 1);
    }

    #[test]
    fn age_uses_the_newest_row() {
        let index = Index::open_in_memory().expect("index");
        let conv = conversation("abcdefgh-0009", "hello", false);
        index
            .record(&conv, "api", "2026-01-01T10:00:00", None)
            .expect("insert");
        let now = Local
            .with_ymd_and_hms(2026, 1, 1, 12, 0, 0)
            .single()
            .expect("time");
        let age = index.age_minutes(now).expect("age").expect("some");
        assert!((age - 120.0).abs() < 0.01);
        assert_eq!(describe_age(None), "sem índice");
    }
}

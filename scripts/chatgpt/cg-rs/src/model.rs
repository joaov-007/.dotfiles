//! Domain types parsed from a `ChatGPT` export or from the web API.
//!
//! The export is a tree: every edit keeps the abandoned branch in `mapping`.
//! Only the branch from `current_node` back to the root is the transcript the
//! author actually sees, so that is the only branch we index.

use std::collections::HashSet;
use std::fmt;

use chrono::{DateTime, Local, NaiveDateTime, TimeZone};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};

use crate::text::{collapse_ws, truncate_chars};

/// Roles that carry conversation text.
const KEEP_ROLES: [&str; 2] = ["user", "assistant"];

/// Content types produced by tools, reasoning, browsing, or memory injection.
const DROP_CONTENT: [&str; 7] = [
    "thoughts",
    "reasoning_recap",
    "user_editable_context",
    "model_editable_context",
    "system_error",
    "execution_output",
    "tether_browsing_display",
];

const PROJECT_PREFIX: &str = "g-p-";
const MAX_ID_LEN: usize = 128;
const MIN_WRITABLE_ID_LEN: usize = 8;
const MAX_WRITABLE_ID_LEN: usize = 64;

/// A `ChatGPT` conversation id, validated before it is ever put in a URL path.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ConversationId(String);

impl ConversationId {
    /// Parse an id from the export or the API. Empty or unsafe ids are rejected.
    #[must_use]
    pub fn parse(raw: &str) -> Option<Self> {
        let raw = raw.trim();
        if raw.is_empty() || raw.len() > MAX_ID_LEN {
            return None;
        }
        if !raw
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
        {
            return None;
        }
        Some(Self(raw.to_owned()))
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// The first `n` characters, used in filenames and listings.
    #[must_use]
    pub fn short(&self, n: usize) -> &str {
        let end = self
            .0
            .char_indices()
            .nth(n)
            .map_or(self.0.len(), |(i, _)| i);
        &self.0[..end]
    }

    /// The stricter guard used before sending a PATCH.
    #[must_use]
    pub fn is_writable(&self) -> bool {
        (MIN_WRITABLE_ID_LEN..=MAX_WRITABLE_ID_LEN).contains(&self.0.len())
    }
}

impl fmt::Display for ConversationId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl AsRef<str> for ConversationId {
    fn as_ref(&self) -> &str {
        &self.0
    }
}

/// A Project id. Projects are gizmos with a `g-p-` id; a bare `g-…` is a
/// custom GPT, and moving that chat would destroy the GPT association.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct ProjectId(String);

impl ProjectId {
    /// Parse a project id, rejecting custom-GPT gizmos.
    #[must_use]
    pub fn parse(raw: &str) -> Option<Self> {
        let raw = raw.trim();
        if !raw.starts_with(PROJECT_PREFIX) || raw.len() > MAX_ID_LEN {
            return None;
        }
        if !raw
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
        {
            return None;
        }
        Some(Self(raw.to_owned()))
    }

    #[must_use]
    pub fn as_str(&self) -> &str {
        &self.0
    }
}

impl fmt::Display for ProjectId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

/// True when a raw gizmo id names a Project (and not a custom GPT).
#[must_use]
pub fn is_project(raw: Option<&str>) -> bool {
    raw.and_then(ProjectId::parse).is_some()
}

/// Who wrote a turn.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Role {
    User,
    Assistant,
}

impl Role {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::User => "user",
            Self::Assistant => "assistant",
        }
    }
}

/// One message in the visible transcript.
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Turn {
    pub role: Role,
    pub text: String,
}

/// A conversation with its visible turns.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Conversation {
    pub id: ConversationId,
    pub title: String,
    pub created: Option<DateTime<Local>>,
    pub archived: bool,
    /// Raw gizmo id: may be a Project (`g-p-…`) or a custom GPT (`g-…`).
    pub project_id: Option<String>,
    pub turns: Vec<Turn>,
}

impl Conversation {
    #[must_use]
    pub fn has_content(&self) -> bool {
        !self.turns.is_empty()
    }

    #[must_use]
    pub fn user_turns(&self) -> usize {
        self.turns.iter().filter(|t| t.role == Role::User).count()
    }

    #[must_use]
    pub fn user_chars(&self) -> usize {
        self.turns
            .iter()
            .filter(|t| t.role == Role::User)
            .map(|t| t.text.chars().count())
            .sum()
    }

    /// Hash of the visible transcript, ignoring whitespace differences.
    #[must_use]
    pub fn body_sha(&self) -> String {
        let blob = self
            .turns
            .iter()
            .map(|t| format!("{}:{}", t.role.as_str(), t.text))
            .collect::<Vec<_>>()
            .join("\n");
        let normalized = collapse_ws(&blob);
        format!("{:x}", Sha256::digest(normalized.trim().as_bytes()))
    }

    /// First user message, folded for duplicate detection (at most 200 chars).
    #[must_use]
    pub fn first_user(&self) -> String {
        self.turns
            .iter()
            .find(|t| t.role == Role::User)
            .map(|t| truncate_chars(&collapse_ws(&t.text), 200).to_lowercase())
            .unwrap_or_default()
    }

    /// Searchable sample stored in the index (at most 6000 chars).
    #[must_use]
    pub fn sample(&self) -> String {
        let all = self
            .turns
            .iter()
            .map(|t| t.text.as_str())
            .collect::<Vec<_>>()
            .join(" ");
        truncate_chars(&collapse_ws(&all), 6000)
    }
}

/// Parse one conversation object. Returns `None` when the id is missing or
/// unsafe, which is the only field we cannot work without.
#[must_use]
pub fn parse_conversation(raw: &Value) -> Option<Conversation> {
    let id = raw
        .get("id")
        .or_else(|| raw.get("conversation_id"))
        .and_then(Value::as_str)
        .and_then(ConversationId::parse)?;

    let mut turns = Vec::new();
    for node in active_branch(raw) {
        let Some(message) = node.get("message").and_then(Value::as_object) else {
            continue;
        };
        let role = message
            .get("author")
            .and_then(|author| author.get("role"))
            .and_then(Value::as_str)
            .map(str::to_lowercase);
        let Some(role) = role.filter(|role| KEEP_ROLES.contains(&role.as_str())) else {
            continue;
        };
        let text = message_text(message);
        if text.is_empty() {
            continue;
        }
        let role = if role == "user" {
            Role::User
        } else {
            Role::Assistant
        };
        turns.push(Turn { role, text });
    }

    let title = collapse_ws(raw.get("title").and_then(Value::as_str).unwrap_or_default());
    let title =
        if title.is_empty() || matches!(title.to_lowercase().as_str(), "new chat" | "novo chat") {
            let first = turns
                .iter()
                .find(|t| t.role == Role::User)
                .map(|t| t.text.lines().next().unwrap_or_default())
                .unwrap_or_default();
            let first = truncate_chars(first, 80);
            let first = first.trim();
            if first.is_empty() {
                "(sem título)".to_owned()
            } else {
                first.to_owned()
            }
        } else {
            title
        };

    let project_id = raw
        .get("gizmo_id")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|raw| !raw.is_empty())
        .map(str::to_owned);

    Some(Conversation {
        id,
        title,
        created: parse_created(raw.get("create_time")),
        archived: raw
            .get("is_archived")
            .and_then(Value::as_bool)
            .unwrap_or(false),
        project_id,
        turns,
    })
}

/// Follow `current_node` -> parent -> root. Falls back to the newest leaf when
/// the export names a node that does not exist.
#[must_use]
pub fn active_branch(raw: &Value) -> Vec<&Value> {
    let Some(mapping) = raw.get("mapping").and_then(Value::as_object) else {
        return Vec::new();
    };
    if mapping.is_empty() {
        return Vec::new();
    }

    let mut current = raw
        .get("current_node")
        .and_then(Value::as_str)
        .filter(|id| mapping.contains_key(*id))
        .map(str::to_owned);

    if current.is_none() {
        current = mapping
            .iter()
            .filter(|(_, node)| is_leaf(node))
            .max_by(|(_, left), (_, right)| create_time(left).total_cmp(&create_time(right)))
            .map(|(id, _)| id.clone());
    }

    let mut chain = Vec::new();
    let mut seen = HashSet::new();
    while let Some(id) = current {
        if !seen.insert(id.clone()) {
            break;
        }
        let Some(node) = mapping.get(&id) else {
            break;
        };
        chain.push(node);
        current = node
            .get("parent")
            .and_then(Value::as_str)
            .map(str::to_owned);
    }
    chain.reverse();
    chain
}

/// Extract only the text a reader sees. Thoughts, tool output, and browsing
/// stubs are machine noise and would skew every keyword score.
#[must_use]
pub fn message_text(message: &serde_json::Map<String, Value>) -> String {
    let Some(content) = message.get("content").and_then(Value::as_object) else {
        return String::new();
    };

    let content_type = content
        .get("content_type")
        .and_then(Value::as_str)
        .unwrap_or_default();
    if DROP_CONTENT.contains(&content_type) {
        return String::new();
    }

    let Some(parts) = content.get("parts").and_then(Value::as_array) else {
        return content
            .get("text")
            .and_then(Value::as_str)
            .map(str::trim)
            .unwrap_or_default()
            .to_owned();
    };

    let mut out = Vec::new();
    for part in parts {
        if let Some(text) = part.as_str() {
            let text = text.trim();
            if !text.is_empty() {
                out.push(text.to_owned());
            }
            continue;
        }
        let Some(part) = part.as_object() else {
            continue;
        };
        let kind = part
            .get("content_type")
            .and_then(Value::as_str)
            .unwrap_or_default();
        if let Some(label) = asset_label(kind) {
            out.push(label.to_owned());
        } else if let Some(text) = part.get("text").and_then(Value::as_str) {
            let text = text.trim();
            if !text.is_empty() {
                out.push(text.to_owned());
            }
        }
    }
    out.join("\n\n")
}

fn asset_label(content_type: &str) -> Option<&'static str> {
    match content_type {
        "image_asset_pointer" => Some("[imagem]"),
        "audio_asset_pointer" => Some("[áudio]"),
        "file" => Some("[arquivo]"),
        "video_asset_pointer" => Some("[vídeo]"),
        _ => None,
    }
}

fn is_leaf(node: &Value) -> bool {
    node.get("children")
        .and_then(Value::as_array)
        .is_none_or(Vec::is_empty)
}

fn create_time(node: &Value) -> f64 {
    node.get("message")
        .and_then(|message| message.get("create_time"))
        .and_then(Value::as_f64)
        .unwrap_or(0.0)
}

fn parse_created(value: Option<&Value>) -> Option<DateTime<Local>> {
    let value = value?;
    if let Some(text) = value.as_str() {
        if text.is_empty() {
            return None;
        }
        if let Ok(parsed) = DateTime::parse_from_rfc3339(text) {
            return Some(parsed.with_timezone(&Local));
        }
        // The export normally uses ISO-8601, but a missing offset happens.
        let naive = NaiveDateTime::parse_from_str(text, "%Y-%m-%dT%H:%M:%S%.f").ok()?;
        return Local.from_local_datetime(&naive).single();
    }
    let seconds = value.as_f64()?;
    if seconds <= 0.0 {
        return None;
    }
    let whole = seconds.floor();
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    let secs = whole as i64;
    #[allow(clippy::cast_possible_truncation, clippy::cast_sign_loss)]
    let nanos = ((seconds - whole) * 1_000_000_000.0).round() as u32;
    Local.timestamp_opt(secs, nanos.min(999_999_999)).single()
}

#[cfg(test)]
mod tests {
    use serde_json::json;

    use super::*;

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

    fn conversation() -> Value {
        json!({
            "id": "6ae22dd8-b474-4000-8000-000000000001",
            "title": "Zram And Swapfile",
            "create_time": 1_700_000_000.0,
            "mapping": {
                "root": node("root", None, "system", "", &["u1"]),
                "u1": node("u1", Some("root"), "user", "  how do I enable zram?  ", &["a1", "u2"]),
                "a1": node("a1", Some("u1"), "assistant", "Use systemd-zram.", &[]),
                "u2": node("u2", Some("u1"), "user", "abandoned edit", &[]),
            },
            "current_node": "a1"
        })
    }

    #[test]
    fn only_the_visible_branch_is_read() {
        let conv = parse_conversation(&conversation()).expect("valid");
        assert_eq!(conv.turns.len(), 2);
        assert_eq!(conv.turns[0].role, Role::User);
        assert_eq!(conv.turns[0].text, "how do I enable zram?");
        assert!(!conv.turns.iter().any(|t| t.text.contains("abandoned")));
    }

    #[test]
    fn missing_current_node_falls_back_to_the_newest_leaf() {
        let mut raw = conversation();
        raw["current_node"] = json!("does-not-exist");
        raw["mapping"]["u2"]["message"]["create_time"] = json!(200.0);
        let conv = parse_conversation(&raw).expect("valid");
        assert_eq!(
            conv.turns.last().map(|t| t.text.as_str()),
            Some("abandoned edit")
        );
    }

    #[test]
    fn system_and_tool_messages_are_dropped() {
        let raw = json!({
            "id": "abcdefgh-1234",
            "mapping": {
                "a": {
                    "id": "a", "parent": null, "children": [],
                    "message": {
                        "author": { "role": "assistant" },
                        "content": { "content_type": "thoughts", "parts": ["secret"] }
                    }
                }
            },
            "current_node": "a"
        });
        let conv = parse_conversation(&raw).expect("valid");
        assert_eq!(conv.turns, Vec::<Turn>::new());
    }

    #[test]
    fn assets_become_labels() {
        let message = json!({
            "content": {
                "content_type": "multimodal_text",
                "parts": [
                    { "content_type": "image_asset_pointer", "asset_pointer": "x" },
                    { "content_type": "text", "text": "look" }
                ]
            }
        });
        let map = message.as_object().expect("object");
        assert_eq!(message_text(map), "[imagem]\n\nlook");
    }

    #[test]
    fn title_falls_back_to_the_first_question() {
        let raw = json!({
            "id": "abcdefgh-1234",
            "title": "New chat",
            "mapping": {
                "u": {
                    "id": "u", "parent": null, "children": [],
                    "message": {
                        "author": { "role": "user" },
                        "content": { "content_type": "text", "parts": ["First line\nsecond"] }
                    }
                }
            },
            "current_node": "u"
        });
        let conv = parse_conversation(&raw).expect("valid");
        assert_eq!(conv.title, "First line");
    }

    #[test]
    fn body_hash_ignores_whitespace_and_id_is_stable() {
        let mut raw = conversation();
        let conv = parse_conversation(&raw).expect("valid");
        raw["mapping"]["u1"]["message"]["content"]["parts"] = json!(["  how   do I enable zram? "]);
        let again = parse_conversation(&raw).expect("valid");
        assert_eq!(conv.body_sha(), again.body_sha());
        assert_eq!(conv.first_user(), "how do i enable zram?");
    }

    #[test]
    fn ids_are_validated_before_url_use() {
        assert!(ConversationId::parse("6ae22dd8-b474").is_some());
        assert!(ConversationId::parse("../../etc/passwd").is_none());
        assert!(ConversationId::parse("").is_none());
        assert!(!ConversationId::parse("short").expect("valid").is_writable());
        assert!(
            ConversationId::parse("6ae22dd8-b474")
                .expect("valid")
                .is_writable()
        );
    }

    #[test]
    fn custom_gpt_ids_are_not_projects() {
        assert!(ProjectId::parse("g-p-123").is_some());
        assert!(ProjectId::parse("g-123").is_none());
        assert!(is_project(Some("g-p-abc")));
        assert!(!is_project(Some("g-abc")));
        assert!(!is_project(None));
    }

    #[test]
    fn epoch_and_iso_dates_are_accepted() {
        let epoch = parse_created(Some(&json!(1_700_000_000.0)));
        let iso = parse_created(Some(&json!("2023-11-14T22:13:20Z")));
        assert!(epoch.is_some());
        assert!(iso.is_some());
        assert_eq!(epoch.map(|d| d.timestamp()), iso.map(|d| d.timestamp()));
        assert!(parse_created(Some(&json!("not a date"))).is_none());
    }
}

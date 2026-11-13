//! Triage plan: project suggestion, verdict, and duplicate detection.
//!
//! Pure functions only. `plan` writes a report, `archive`/`organize` read the
//! same decisions; keeping it side-effect free means the same rules drive the
//! dry-run and the live run.

use std::collections::{HashMap, HashSet};

use serde::{Deserialize, Serialize};

use crate::classify::classify;
use crate::store::StoredConversation;

/// What should happen to a conversation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Verdict {
    Keep,
    Review,
    Archive,
    Delete,
    Unknown,
}

impl Verdict {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Keep => "keep",
            Self::Review => "review",
            Self::Archive => "archive",
            Self::Delete => "delete",
            Self::Unknown => "unknown",
        }
    }

    #[must_use]
    pub fn parse(value: &str) -> Option<Self> {
        match value {
            "keep" => Some(Self::Keep),
            "review" => Some(Self::Review),
            "archive" => Some(Self::Archive),
            "delete" => Some(Self::Delete),
            "unknown" => Some(Self::Unknown),
            _ => None,
        }
    }
}

/// Why two chats look like the same conversation.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DupeReason {
    SameBody,
    SameOpening,
}

impl DupeReason {
    #[must_use]
    pub fn label(self) -> &'static str {
        match self {
            Self::SameBody => "mesma conversa",
            Self::SameOpening => "mesma pergunta inicial",
        }
    }
}

/// One row plus the decisions taken for it.
#[derive(Debug, Clone)]
pub struct PlannedConversation {
    pub conversation: StoredConversation,
    pub project: String,
    pub hits: i32,
    pub runner_up: i32,
    pub verdict: Verdict,
    pub dupe: Option<DupeReason>,
}

impl PlannedConversation {
    /// Why this row is in the archive/delete pile.
    #[must_use]
    pub fn trash_reason(&self) -> String {
        if let Some(dupe) = self.dupe {
            return dupe.label().to_owned();
        }
        if self.conversation.turns == 0 {
            "sem mensagens".to_owned()
        } else {
            "pergunta única".to_owned()
        }
    }
}

/// Bucket one row. Kept separate so the rules are testable as a table.
#[must_use]
pub fn bucket(
    has_content: bool,
    turns: i64,
    user_chars: i64,
    user_turns: i64,
    duplicate: bool,
) -> Verdict {
    if !has_content {
        return Verdict::Unknown;
    }
    if turns == 0 || user_chars == 0 {
        return Verdict::Delete;
    }
    if duplicate {
        return Verdict::Archive;
    }
    // One question, at most one answer, and a short question: the classic
    // throwaway chat that only adds noise to the sidebar.
    if user_turns <= 1 && turns <= 2 && user_chars < 300 {
        return Verdict::Archive;
    }
    Verdict::Keep
}

/// Attach project + verdict to every row. Shared by `plan`, `archive`, and
/// `organize`.
#[must_use]
pub fn build_plan(rows: &[StoredConversation]) -> Vec<PlannedConversation> {
    let dupes = duplicate_map(rows);

    rows.iter()
        .map(|row| {
            let classification = classify(&format!("{} {}", row.title, row.sample));
            let dupe = dupes.get(row.id.as_str()).copied();
            let mut verdict = bucket(
                row.has_content,
                row.turns,
                row.user_chars,
                row.user_turns,
                dupe.is_some(),
            );
            if verdict == Verdict::Keep
                && (classification.project.is_none()
                    || classification.score - classification.runner_up < 2)
            {
                verdict = Verdict::Review;
            }
            PlannedConversation {
                conversation: row.clone(),
                project: classification.project.unwrap_or("Inbox").to_owned(),
                hits: classification.score,
                runner_up: classification.runner_up,
                verdict,
                dupe,
            }
        })
        .collect()
}

/// Chats the archive command may touch: archive/delete and not already archived.
#[must_use]
pub fn archive_candidates(plans: &[PlannedConversation]) -> Vec<&PlannedConversation> {
    plans
        .iter()
        .filter(|plan| {
            matches!(plan.verdict, Verdict::Archive | Verdict::Delete)
                && !plan.conversation.archived
        })
        .collect()
}

/// Counts used by `plan`, `archive stats`, and the daemon summary.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub struct PlanSummary {
    pub indexed: usize,
    pub keep: usize,
    pub review: usize,
    pub archive: usize,
    pub delete: usize,
    pub unknown: usize,
    pub archived: usize,
    pub candidates: usize,
}

impl PlanSummary {
    #[must_use]
    pub fn from_plans(plans: &[PlannedConversation]) -> Self {
        let mut summary = Self {
            indexed: plans.len(),
            ..Self::default()
        };
        for plan in plans {
            match plan.verdict {
                Verdict::Keep => summary.keep += 1,
                Verdict::Review => summary.review += 1,
                Verdict::Archive => summary.archive += 1,
                Verdict::Delete => summary.delete += 1,
                Verdict::Unknown => summary.unknown += 1,
            }
            if plan.conversation.archived {
                summary.archived += 1;
            }
        }
        summary.candidates = plans
            .iter()
            .filter(|plan| {
                matches!(plan.verdict, Verdict::Archive | Verdict::Delete)
                    && !plan.conversation.archived
            })
            .count();
        summary
    }
}

fn duplicate_map(rows: &[StoredConversation]) -> HashMap<String, DupeReason> {
    let mut by_sha: HashMap<&str, Vec<usize>> = HashMap::new();
    let mut by_first: HashMap<&str, Vec<usize>> = HashMap::new();

    for (position, row) in rows.iter().enumerate() {
        if !row.body_sha.is_empty() && row.user_chars >= 200 {
            by_sha
                .entry(row.body_sha.as_str())
                .or_default()
                .push(position);
        }
        if !row.first_user.is_empty() && row.first_user.chars().count() >= 40 {
            by_first
                .entry(row.first_user.as_str())
                .or_default()
                .push(position);
        }
    }

    let mut dupes = HashMap::new();
    for group in ordered_groups(by_sha) {
        mark_group(rows, &group, true, &mut dupes);
    }
    for group in ordered_groups(by_first) {
        mark_group(rows, &group, false, &mut dupes);
    }
    dupes
}

fn ordered_groups(groups: HashMap<&str, Vec<usize>>) -> Vec<Vec<usize>> {
    let mut groups = groups.into_values().collect::<Vec<_>>();
    groups.retain(|group| group.len() > 1);
    groups.sort_by_key(|group| group.first().copied().unwrap_or(usize::MAX));
    groups
}

fn mark_group(
    rows: &[StoredConversation],
    group: &[usize],
    same_body_group: bool,
    dupes: &mut HashMap<String, DupeReason>,
) {
    let mut ordered = group.to_vec();
    ordered.sort_by(|left, right| {
        let left = rows[*left].created_ts.unwrap_or(0.0);
        let right = rows[*right].created_ts.unwrap_or(0.0);
        left.total_cmp(&right)
    });
    let same_body = same_body_group
        || ordered
            .iter()
            .map(|position| rows[*position].body_sha.as_str())
            .collect::<HashSet<_>>()
            .len()
            == 1;
    let reason = if same_body {
        DupeReason::SameBody
    } else {
        DupeReason::SameOpening
    };
    for position in ordered.into_iter().skip(1) {
        dupes.entry(rows[position].id.to_string()).or_insert(reason);
    }
}

#[cfg(test)]
mod tests {
    use crate::model::ConversationId;

    use super::*;

    fn row(id: &str, title: &str, turns: i64, user_chars: i64, created: f64) -> StoredConversation {
        StoredConversation {
            id: ConversationId::parse(id).expect("id"),
            title: title.to_owned(),
            created_ts: Some(created),
            turns,
            user_turns: turns / 2,
            user_chars,
            body_sha: format!("sha-{id}"),
            first_user: "x".repeat(40),
            sample: String::new(),
            archived: false,
            has_content: true,
            gone: false,
            project_id: None,
            source_file: None,
            indexed_at: String::new(),
        }
    }

    #[test]
    fn bucket_table() {
        assert_eq!(bucket(false, 5, 500, 2, false), Verdict::Unknown);
        assert_eq!(bucket(true, 0, 0, 0, false), Verdict::Delete);
        assert_eq!(bucket(true, 4, 0, 2, false), Verdict::Delete);
        assert_eq!(bucket(true, 4, 500, 2, true), Verdict::Archive);
        assert_eq!(bucket(true, 2, 299, 1, false), Verdict::Archive);
        assert_eq!(bucket(true, 2, 300, 1, false), Verdict::Keep);
        assert_eq!(bucket(true, 3, 900, 2, false), Verdict::Keep);
    }

    #[test]
    fn duplicates_keep_the_oldest_and_archive_the_rest() {
        let mut first = row("abcdefgh-0001", "Zram And Swapfile", 10, 900, 10.0);
        let mut second = row("abcdefgh-0002", "Zram And Swapfile", 10, 900, 20.0);
        first.body_sha = "same".to_owned();
        second.body_sha = "same".to_owned();
        let plans = build_plan(&[second, first]);
        assert_eq!(plans[0].verdict, Verdict::Archive);
        assert_eq!(plans[0].trash_reason(), "mesma conversa");
        assert_eq!(plans[1].dupe, None);
    }

    #[test]
    fn same_opening_with_a_different_body_is_a_duplicate_too() {
        let mut first = row("abcdefgh-0003", "Pacman update", 10, 900, 10.0);
        let mut second = row("abcdefgh-0004", "Pacman update again", 10, 900, 20.0);
        first.first_user = "how do i fix the bootloader after an update".to_owned();
        second.first_user = first.first_user.clone();
        first.body_sha = "one".to_owned();
        second.body_sha = "two".to_owned();
        let plans = build_plan(&[first, second]);
        assert_eq!(plans[1].dupe, Some(DupeReason::SameOpening));
        assert_eq!(plans[1].verdict, Verdict::Archive);
    }

    #[test]
    fn unclassified_keepers_go_to_review() {
        let mut loose = row("abcdefgh-0005", "a private thought", 10, 900, 10.0);
        loose.first_user = "short".to_owned();
        let plans = build_plan(&[loose]);
        assert_eq!(plans[0].verdict, Verdict::Review);
        assert_eq!(plans[0].project, "Inbox");
    }

    #[test]
    fn classified_keepers_stay_keep() {
        let mut keep = row("abcdefgh-0006", "pacman systemd arch linux", 10, 900, 10.0);
        keep.first_user = "short".to_owned();
        let plans = build_plan(&[keep]);
        assert_eq!(plans[0].verdict, Verdict::Keep);
        assert_eq!(plans[0].project, "Linux & Arch");
    }

    #[test]
    fn archived_rows_are_not_candidates() {
        let mut archived = row("abcdefgh-0007", "one shot", 2, 100, 10.0);
        archived.archived = true;
        let plans = build_plan(&[archived]);
        assert!(archive_candidates(&plans).is_empty());
        assert_eq!(PlanSummary::from_plans(&plans).archived, 1);
    }
}

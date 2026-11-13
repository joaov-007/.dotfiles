//! Group keeper chats into Projects before any request is sent.
//!
//! The rules mirror the Python tool exactly, because `organize` and its undo
//! journal depend on them:
//!
//! * never file a chat the plan wants to archive/delete;
//! * never touch a chat tied to a custom GPT (`g-…`), since moving it would
//!   overwrite the GPT association;
//! * reuse an existing Project whose folded name matches;
//! * drop categories below `--min`, except the fallback pile;
//! * put the fallback pile last so it does not outrank real topics.

use std::collections::HashMap;

use crate::api::Project;
use crate::model::{ProjectId, is_project};
use crate::plan::{PlannedConversation, Verdict};
use crate::text::fold;

/// Fold a category/project name so `Linux & Arch` == `linux arch`.
#[must_use]
pub fn project_key(name: &str) -> String {
    fold(name)
        .chars()
        .map(|ch| if ch.is_ascii_alphanumeric() { ch } else { ' ' })
        .collect::<String>()
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

/// One destination Project, with the chats that belong in it.
#[derive(Debug, Clone)]
pub struct ProjectTarget<'a> {
    pub name: String,
    /// `None` means the Project still has to be created.
    pub project_id: Option<ProjectId>,
    pub categories: Vec<String>,
    pub items: Vec<&'a PlannedConversation>,
}

/// A category ignored because it was too small and has no matching Project.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SkippedGroup {
    pub category: String,
    pub name: String,
    pub count: usize,
}

/// Build the Project plan. Pure: the caller decides whether to apply it.
#[must_use]
pub fn plan_projects<'a, S: std::hash::BuildHasher>(
    plans: &'a [PlannedConversation],
    existing: &[Project],
    aliases: &HashMap<String, String, S>,
    minimum: usize,
    fallback: Option<&str>,
) -> (Vec<ProjectTarget<'a>>, Vec<SkippedGroup>) {
    let fallback = fallback.map(str::trim).filter(|name| !name.is_empty());
    let fallback_key = fallback.map(project_key);

    // Stable, insertion-ordered groups: ties keep the order the index gave.
    let mut order: Vec<String> = Vec::new();
    let mut groups: HashMap<String, (String, Vec<&PlannedConversation>)> = HashMap::new();

    for plan in plans {
        let row = &plan.conversation;
        if !row.has_content || row.archived || row.gone {
            continue;
        }
        if !matches!(plan.verdict, Verdict::Keep | Verdict::Review) {
            continue;
        }
        if row
            .project_id
            .as_deref()
            .is_some_and(|raw| !is_project(Some(raw)))
        {
            continue;
        }

        let category = if let Some(fallback) = fallback {
            if plan.verdict == Verdict::Review || plan.project == "Inbox" {
                fallback
            } else if plan.verdict == Verdict::Keep && !plan.project.is_empty() {
                plan.project.as_str()
            } else {
                fallback
            }
        } else if plan.verdict == Verdict::Keep
            && !plan.project.is_empty()
            && plan.project != "Inbox"
        {
            plan.project.as_str()
        } else {
            continue;
        };

        let key = project_key(category);
        groups
            .entry(key.clone())
            .or_insert_with(|| {
                order.push(key);
                (category.to_owned(), Vec::new())
            })
            .1
            .push(plan);
    }

    let existing_by_key: HashMap<String, &Project> = existing
        .iter()
        .map(|project| (project_key(&project.name), project))
        .collect();

    let mut merged_order: Vec<String> = Vec::new();
    let mut merged: HashMap<String, ProjectTarget<'a>> = HashMap::new();
    let mut skipped = Vec::new();

    for key in order {
        let Some((category, items)) = groups.remove(&key) else {
            continue;
        };
        let name = aliases
            .get(&key)
            .map(|name| name.trim().to_owned())
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| category.clone());
        let slot_key = project_key(&name);
        let found = existing_by_key.get(&slot_key).copied();

        // The fallback pile exists even with one chat; everything else has to
        // earn its place in the sidebar.
        if found.is_none() && Some(&key) != fallback_key.as_ref() && items.len() < minimum {
            skipped.push(SkippedGroup {
                category,
                name,
                count: items.len(),
            });
            continue;
        }

        let target = merged.entry(slot_key.clone()).or_insert_with(|| {
            merged_order.push(slot_key);
            ProjectTarget {
                name,
                project_id: found.map(|project| project.id.clone()),
                categories: Vec::new(),
                items: Vec::new(),
            }
        });
        if !target.categories.contains(&category) {
            target.categories.push(category);
        }
        target.items.extend(items);
    }

    let mut targets: Vec<ProjectTarget<'a>> = merged_order
        .into_iter()
        .filter_map(|key| merged.remove(&key))
        .collect();
    // Biggest pile first; the fallback pile is pushed to the bottom.
    targets.sort_by_key(|target| std::cmp::Reverse(target.items.len()));
    if let Some(fallback_key) = fallback_key {
        targets.sort_by_key(|target| project_key(&target.name) == fallback_key);
    }
    (targets, skipped)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{ConversationId, ProjectId};
    use crate::plan::{DupeReason, Verdict};
    use crate::store::StoredConversation;

    fn row(id: &str, project: Option<&str>) -> StoredConversation {
        StoredConversation {
            id: ConversationId::parse(id).expect("id"),
            title: "t".to_owned(),
            created_ts: None,
            turns: 4,
            user_turns: 2,
            user_chars: 400,
            body_sha: String::new(),
            first_user: String::new(),
            sample: String::new(),
            archived: false,
            has_content: true,
            gone: false,
            project_id: project.map(str::to_owned),
            source_file: None,
            indexed_at: String::new(),
        }
    }

    fn plan(id: &str, project: &str, verdict: Verdict) -> PlannedConversation {
        PlannedConversation {
            conversation: row(id, None),
            project: project.to_owned(),
            hits: 3,
            runner_up: 0,
            verdict,
            dupe: None::<DupeReason>,
        }
    }

    fn project(name: &str, id: &str) -> Project {
        Project {
            id: ProjectId::parse(id).expect("project id"),
            name: name.to_owned(),
        }
    }

    #[test]
    fn keys_fold_case_accents_and_separators() {
        assert_eq!(project_key("Linux & Arch"), "linux arch");
        assert_eq!(project_key("Música-Dev"), "musica dev");
        assert_eq!(project_key("  "), "");
    }

    #[test]
    fn small_categories_are_skipped_unless_a_project_exists() {
        let plans = vec![
            plan("aaaaaaaa-1", "Rust", Verdict::Keep),
            plan("aaaaaaaa-2", "Rust", Verdict::Keep),
            plan("aaaaaaaa-3", "Rust", Verdict::Keep),
            plan("bbbbbbbb-1", "Go", Verdict::Keep),
        ];
        let (targets, skipped) = plan_projects(&plans, &[], &HashMap::new(), 3, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].name, "Rust");
        assert_eq!(skipped.len(), 1);
        assert_eq!(skipped[0].category, "Go");
    }

    #[test]
    fn an_existing_project_is_reused_by_folded_name() {
        let plans = vec![plan("aaaaaaaa-1", "Linux & Arch", Verdict::Keep)];
        let existing = vec![project("linux arch", "g-p-existing")];
        let (targets, _) = plan_projects(&plans, &existing, &HashMap::new(), 3, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(
            targets[0].project_id.as_ref().map(ProjectId::as_str),
            Some("g-p-existing")
        );
    }

    #[test]
    fn the_fallback_pile_is_always_created_and_sorted_last() {
        let plans = vec![
            plan("aaaaaaaa-1", "Rust", Verdict::Keep),
            plan("aaaaaaaa-2", "Rust", Verdict::Keep),
            plan("aaaaaaaa-3", "Rust", Verdict::Keep),
            plan("bbbbbbbb-1", "Inbox", Verdict::Review),
        ];
        let (targets, skipped) = plan_projects(&plans, &[], &HashMap::new(), 3, Some("Inbox"));
        assert_eq!(skipped.len(), 0);
        assert_eq!(targets.len(), 2);
        assert_eq!(targets[0].name, "Rust");
        assert_eq!(targets[1].name, "Inbox");
    }

    #[test]
    fn aliases_redirect_a_category_to_an_existing_project() {
        let plans = vec![
            plan("aaaaaaaa-1", "Linux & Arch", Verdict::Keep),
            plan("aaaaaaaa-2", "Linux & Arch", Verdict::Keep),
            plan("aaaaaaaa-3", "Linux & Arch", Verdict::Keep),
        ];
        let aliases = HashMap::from([("linux arch".to_owned(), "Nix".to_owned())]);
        let existing = vec![project("nix", "g-p-nix")];
        let (targets, _) = plan_projects(&plans, &existing, &aliases, 3, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].name, "Nix");
        assert_eq!(targets[0].categories, ["Linux & Arch"]);
    }

    #[test]
    fn aliased_categories_merge_into_one_project() {
        let plans = vec![
            plan("aaaaaaaa-1", "Rust", Verdict::Keep),
            plan("aaaaaaaa-2", "Rust", Verdict::Keep),
            plan("aaaaaaaa-3", "Rust", Verdict::Keep),
            plan("bbbbbbbb-1", "Nix", Verdict::Keep),
            plan("bbbbbbbb-2", "Nix", Verdict::Keep),
            plan("bbbbbbbb-3", "Nix", Verdict::Keep),
        ];
        let aliases = HashMap::from([("rust".to_owned(), "Nix".to_owned())]);
        let existing = vec![project("nix", "g-p-nix")];
        let (targets, _) = plan_projects(&plans, &existing, &aliases, 3, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].items.len(), 6);
        assert_eq!(targets[0].categories, ["Rust", "Nix"]);
    }

    #[test]
    fn categories_that_fold_to_the_same_key_are_one_group() {
        let plans = vec![
            plan("aaaaaaaa-1", "Linux", Verdict::Keep),
            plan("aaaaaaaa-2", "Linux", Verdict::Keep),
            plan("aaaaaaaa-3", "Linux", Verdict::Keep),
            plan("bbbbbbbb-1", "linux", Verdict::Keep),
            plan("bbbbbbbb-2", "linux", Verdict::Keep),
            plan("bbbbbbbb-3", "linux", Verdict::Keep),
        ];
        let (targets, _) = plan_projects(&plans, &[], &HashMap::new(), 3, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].items.len(), 6);
        assert_eq!(targets[0].categories, ["Linux"]);
    }

    #[test]
    fn rows_that_must_not_move_are_ignored() {
        let mut archived = plan("aaaaaaaa-2", "Rust", Verdict::Keep);
        archived.conversation.archived = true;
        let mut gone = plan("aaaaaaaa-3", "Rust", Verdict::Keep);
        gone.conversation.gone = true;
        let mut empty = plan("aaaaaaaa-4", "Rust", Verdict::Keep);
        empty.conversation.has_content = false;
        let mut gpt = plan("aaaaaaaa-5", "Rust", Verdict::Keep);
        gpt.conversation.project_id = Some("g-custom-gpt".to_owned());
        let trash = plan("aaaaaaaa-6", "Rust", Verdict::Archive);

        let plans = vec![
            plan("aaaaaaaa-1", "Rust", Verdict::Keep),
            archived,
            gone,
            empty,
            gpt,
            trash,
        ];
        let (targets, skipped) = plan_projects(&plans, &[], &HashMap::new(), 1, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].items.len(), 1);
        assert_eq!(skipped.len(), 0);
    }

    #[test]
    fn without_a_fallback_unplaced_chats_stay_loose() {
        let plans = vec![
            plan("aaaaaaaa-1", "Rust", Verdict::Keep),
            plan("bbbbbbbb-1", "Inbox", Verdict::Review),
        ];
        let (targets, skipped) = plan_projects(&plans, &[], &HashMap::new(), 1, None);
        assert_eq!(targets.len(), 1);
        assert_eq!(targets[0].name, "Rust");
        assert_eq!(skipped.len(), 0);
    }
}

//! `cg export`: one Markdown note per conversation, grouped by Project.
//!
//! Offline and deterministic: bodies come from the cache written by
//! `cg sync --deep`, and rows without a cached body fall back to metadata only.
//! Notes edited by hand are left alone unless `--overwrite` is given.

#[cfg(test)]
use std::path::Path;

use crate::cli::ExportArgs;
use crate::config::Paths;
use crate::conv_cache;
use crate::error::{Error, Result};
use crate::model::{Conversation, parse_conversation};
use crate::note;
use crate::plan::{PlannedConversation, Verdict, build_plan};
use crate::store::{Index, StoredConversation};

/// Filters applied before writing anything.
struct Filter<'a> {
    only_project: Option<&'a str>,
    verdict: Option<Verdict>,
    archived_only: bool,
    not_archived: bool,
    skip_empty: bool,
}

impl Filter<'_> {
    fn keeps(&self, plan: &PlannedConversation) -> bool {
        let row = &plan.conversation;
        if self
            .only_project
            .is_some_and(|project| plan.project != project)
        {
            return false;
        }
        if self.verdict.is_some_and(|verdict| plan.verdict != verdict) {
            return false;
        }
        if self.archived_only && !row.archived {
            return false;
        }
        if self.not_archived && row.archived {
            return false;
        }
        true
    }
}

/// Summary counters shown at the end.
#[derive(Debug, Default)]
struct Tally {
    written: usize,
    unchanged: usize,
    kept: usize,
    skipped: usize,
    failed: usize,
}

pub fn run(paths: &Paths, args: &ExportArgs) -> Result<i32> {
    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }

    let verdict = match args.verdict.as_deref() {
        Some(value) => Some(
            Verdict::parse(value)
                .ok_or_else(|| Error::usage(format!("veredito desconhecido: {value:?}")))?,
        ),
        None => None,
    };
    let filter = Filter {
        only_project: args.only_project.as_deref(),
        verdict,
        archived_only: args.archived_only,
        not_archived: args.not_archived,
        skip_empty: args.skip_empty,
    };

    let outdir = args
        .outdir
        .clone()
        .unwrap_or_else(|| paths.export_dir.clone());
    std::fs::create_dir_all(&outdir)?;

    let mut tally = Tally::default();
    for plan in build_plan(&rows) {
        let row = &plan.conversation;
        if !filter.keeps(&plan) {
            tally.skipped += 1;
            continue;
        }
        let conversation = load(paths, row);
        if filter.skip_empty && conversation.turns.is_empty() {
            tally.skipped += 1;
            continue;
        }

        let folder = outdir.join(note::project_dir(&plan.project));
        let path = folder.join(note::file_name(&conversation));
        let text = note::render(&conversation, Some(&plan.project));
        match note::write_note(&path, &text, args.overwrite) {
            Ok(note::Outcome::Written) => tally.written += 1,
            Ok(note::Outcome::Unchanged) => tally.unchanged += 1,
            Ok(note::Outcome::Kept) => tally.kept += 1,
            Err(error) => {
                tally.failed += 1;
                eprintln!("aviso: não escreveu {}: {error}", path.display());
            }
        }
    }

    println!("saída      : {}", outdir.display());
    println!("exportados : {}", tally.written);
    if tally.unchanged > 0 {
        println!("inalterados: {}", tally.unchanged);
    }
    if tally.kept > 0 {
        println!(
            "preservados: {} (editado à mão; use --overwrite para substituir)",
            tally.kept
        );
    }
    if tally.skipped > 0 {
        println!("ignorados  : {}", tally.skipped);
    }
    if tally.failed > 0 {
        println!("falhas     : {}", tally.failed);
    }
    println!("\nfeito.");
    Ok(i32::from(tally.failed > 0))
}

/// Cached body when available; otherwise the metadata the index already has.
fn load(paths: &Paths, row: &StoredConversation) -> Conversation {
    if let Some(conversation) =
        conv_cache::read(paths, &row.id).and_then(|raw| parse_conversation(&raw))
    {
        return conversation;
    }
    Conversation {
        id: row.id.clone(),
        title: row.title.clone(),
        created: row.created_at(),
        archived: row.archived,
        project_id: row.project_id.clone(),
        turns: Vec::new(),
    }
}

/// Exposed for tests and for `cg daemon` reuse.
#[must_use]
pub fn export_dir(paths: &Paths, args: &ExportArgs) -> std::path::PathBuf {
    args.outdir
        .clone()
        .unwrap_or_else(|| paths.export_dir.clone())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn export_dir_prefers_the_flag() {
        let paths = Paths::rooted(Path::new("/tmp/root"));
        let args = ExportArgs {
            outdir: Some(std::path::PathBuf::from("/tmp/out")),
            only_project: None,
            verdict: None,
            archived_only: false,
            not_archived: false,
            skip_empty: false,
            overwrite: false,
        };
        assert_eq!(export_dir(&paths, &args), Path::new("/tmp/out"));
    }
}

//! `cg plan`: offline triage report.

use chrono::Local;

use crate::config::Paths;
use crate::error::{Error, Result};
use crate::plan::{PlanSummary, build_plan};
use crate::report::{ReportContext, render};
use crate::store::Index;

/// Read the index, apply the rules, and write `plan-*.md` + `plan-*.tsv`.
///
/// This command never touches the network and never writes to the account.
pub fn run(paths: &Paths, days: i64) -> Result<()> {
    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }

    let plans = build_plan(&rows);
    let summary = PlanSummary::from_plans(&plans);
    let now = Local::now();
    let report = render(
        &plans,
        &ReportContext {
            db_path: &paths.db,
            days,
            now,
        },
    );

    paths.ensure_state()?;
    let stamp = now.format("%Y%m%d-%H%M").to_string();
    let markdown_path = paths.reports.join(format!("plan-{stamp}.md"));
    let tsv_path = paths.reports.join(format!("plan-{stamp}.tsv"));
    std::fs::write(&markdown_path, report.markdown)?;
    std::fs::write(&tsv_path, report.tsv)?;

    let projects = plans
        .iter()
        .filter(|plan| {
            matches!(
                plan.verdict,
                crate::plan::Verdict::Keep | crate::plan::Verdict::Review
            )
        })
        .map(|plan| plan.project.as_str())
        .collect::<std::collections::BTreeSet<_>>()
        .len();

    println!("conversas  : {}", summary.indexed);
    println!(
        "manter     : {}  ({projects} projects sugeridos)",
        summary.keep
    );
    println!("revisar    : {}", summary.review);
    println!("arquivar   : {}", summary.archive);
    println!("apagar     : {}", summary.delete);
    if summary.unknown > 0 {
        println!("sem conteúdo: {}  (rode: cg sync --deep)", summary.unknown);
    }
    println!("\nplano      : {}", markdown_path.display());
    println!("tabela     : {}", tsv_path.display());
    println!("\nnada foi alterado no site — as ações são suas.");
    Ok(())
}

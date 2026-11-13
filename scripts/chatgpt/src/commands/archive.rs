//! `cg archive`: reversible archiving plus the offline inspection views.

use chrono::Local;

use crate::api::set_archived;
use crate::auth::authenticate;
use crate::cli::{ArchiveAction, ArchiveArgs, ArchiveRunArgs};
use crate::config::Paths;
use crate::error::{Error, Result};
use crate::journal::{self, Entry};
use crate::live;
use crate::lock::{self, RunLock};
use crate::plan::{Verdict, archive_candidates, build_plan};
use crate::store::Index;
use crate::text::{collapse_ws, truncate_chars};

/// Dispatch: no subcommand is the dry-run of `run`; the rest is offline.
pub fn run(paths: &Paths, args: &ArchiveArgs) -> Result<i32> {
    match &args.action {
        None => run_writes(paths, &args.run),
        Some(ArchiveAction::Run(options)) => run_writes(paths, options),
        Some(ArchiveAction::List {
            candidates,
            limit,
            urls,
        }) => list(paths, *candidates, *limit, *urls),
        Some(ArchiveAction::Show { id }) => show(paths, id),
        Some(ArchiveAction::Stats) => stats(paths),
    }
}

fn run_writes(paths: &Paths, args: &ArchiveRunArgs) -> Result<i32> {
    let _lease: RunLock = lock::acquire(&paths.lock)?;

    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }

    let plans = build_plan(&rows);
    let mut targets = archive_candidates(&plans);
    if let Some(path) = &args.ids {
        let wanted = live::read_ids(path)?;
        let wanted = wanted.iter().collect::<std::collections::HashSet<_>>();
        targets.retain(|plan| wanted.contains(&plan.conversation.id));
    }

    let limit = if args.limit == 0 {
        targets.len()
    } else {
        args.limit
    };
    let batch = &targets[..limit.min(targets.len())];
    if batch.is_empty() {
        println!("nada a arquivar — o índice já está limpo.");
        return Ok(0);
    }

    if !args.yes {
        println!(
            "arquivaria {} conversas (de {} candidatas):",
            batch.len(),
            targets.len()
        );
        for plan in batch.iter().take(15) {
            let row = &plan.conversation;
            println!(
                "  [{}] {}  https://chatgpt.com/c/{}",
                plan.trash_reason(),
                truncate_chars(&row.title, 64),
                row.id
            );
        }
        if batch.len() > 15 {
            println!("  … e mais {}", batch.len() - 15);
        }
        println!("\ndry-run: nada foi enviado. aplicar com --yes (limite: --limit N)");
        return Ok(0);
    }

    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(args.sleep, live::RETRIES);
    let session = authenticate(&mut client, &args.auth, paths)?;
    let token = session.access_token;

    paths.ensure_state()?;
    let now = live::now_string();
    let path = journal::path_for(&paths.reports, "archive", Local::now());
    let mut journal = journal::create(&path)?;
    let backup = journal::snapshot_for(&paths.reports, "archive-backup", Local::now());
    index.snapshot(&backup)?;

    let mut done = 0_usize;
    let mut failed = 0_usize;
    let total = batch.len();
    for (position, plan) in batch.iter().enumerate() {
        let row = &plan.conversation;
        if !row.id.is_writable() {
            failed += 1;
            println!("[{:>3}/{total}] id inválido  {}", position + 1, row.id);
            continue;
        }

        let response = set_archived(&mut client, &base, &token, &row.id, true)?;
        if let Some(error) = live::abort_for(response.status) {
            println!(
                "\nabortado: HTTP {} — sessão inválida ou rate limit.\n\
                 arquivadas até aqui: {done}. log: {}",
                response.status,
                journal.path().display()
            );
            return Err(error);
        }
        let ok = (200..300).contains(&response.status);
        journal.append(&Entry::archived(row.id.as_str(), response.status, ok, &now))?;

        if ok {
            done += 1;
            index.set_archived(&row.id, true)?;
            println!(
                "[{:>3}/{total}] ok        {}",
                position + 1,
                truncate_chars(&row.title, 60)
            );
        } else {
            failed += 1;
            println!(
                "[{:>3}/{total}] HTTP {}  {}",
                position + 1,
                response.status,
                truncate_chars(&row.title, 60)
            );
        }
    }

    println!("\narquivadas: {done} · falhas: {failed}");
    println!("log      : {}", journal.path().display());
    println!("backup   : {}", backup.display());
    println!("desfazer : cg unarchive --log {}", journal.path().display());
    Ok(i32::from(failed != 0))
}

fn list(paths: &Paths, candidates: bool, limit: usize, urls: bool) -> Result<i32> {
    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }
    let plans = build_plan(&rows);

    let (title, items) = if candidates {
        let items = plans
            .iter()
            .filter(|plan| {
                matches!(plan.verdict, Verdict::Archive | Verdict::Delete)
                    && !plan.conversation.archived
            })
            .collect::<Vec<_>>();
        ("candidatas a arquivar", items)
    } else {
        let mut items = plans
            .iter()
            .filter(|plan| plan.conversation.archived)
            .collect::<Vec<_>>();
        items.sort_by(|left, right| {
            right
                .conversation
                .created_ts
                .partial_cmp(&left.conversation.created_ts)
                .unwrap_or(std::cmp::Ordering::Equal)
        });
        ("arquivadas (estado do último sync)", items)
    };

    let shown = if limit == 0 {
        items.as_slice()
    } else {
        &items[..limit.min(items.len())]
    };
    println!("{title}: {}", items.len());
    for plan in shown {
        let row = &plan.conversation;
        let reason = if candidates {
            format!("  {}", plan.trash_reason())
        } else {
            String::new()
        };
        let url = if urls {
            format!("  https://chatgpt.com/c/{}", row.id)
        } else {
            String::new()
        };
        println!(
            "  {}  {}  {:>3} msgs  {}{reason}{url}",
            row.id.short(8),
            row.date(),
            row.turns,
            truncate_chars(&row.title, 60)
        );
    }
    if items.len() > shown.len() {
        println!(
            "  … e mais {} (use --limit 0 para ver todas)",
            items.len() - shown.len()
        );
    }
    if items.is_empty() && !candidates {
        println!("  nada aqui ainda — `cg archive` mostra o que entraria.");
    }
    Ok(0)
}

fn show(paths: &Paths, needle: &str) -> Result<i32> {
    let index = Index::open(&paths.db)?;
    let matches = index.find_prefix(needle)?;
    if matches.is_empty() {
        return Err(Error::usage(format!(
            "nenhum conv_id começa com {needle:?}"
        )));
    }
    if matches.len() > 1 {
        println!("{} conversas começam com {needle:?}:", matches.len());
        for row in matches.iter().take(20) {
            println!("  {}  {}", row.id, truncate_chars(&row.title, 60));
        }
        return Err(Error::usage("informe mais caracteres do id"));
    }
    let row = &matches[0];
    let active = index.all_active()?;
    let plan = build_plan(&active)
        .into_iter()
        .find(|plan| plan.conversation.id == row.id);

    println!("id       : {}", row.id);
    println!("título   : {}", collapse_ws(&row.title));
    println!("criada   : {}", row.date());
    println!(
        "mensagens: {} ({} suas, {} chars)",
        row.turns, row.user_turns, row.user_chars
    );
    println!("arquivada: {}", if row.archived { "sim" } else { "não" });
    println!("project  : {}", row.project_id.as_deref().unwrap_or("—"));
    if let Some(plan) = plan {
        let why = if matches!(plan.verdict, Verdict::Archive | Verdict::Delete) {
            format!(" — {}", plan.trash_reason())
        } else {
            String::new()
        };
        println!("veredito : {}{why}", plan.verdict.as_str());
    }
    if !row.first_user.is_empty() {
        println!("primeira : {}", truncate_chars(&row.first_user, 100));
    }
    println!("link     : https://chatgpt.com/c/{}", row.id);
    Ok(0)
}

fn stats(paths: &Paths) -> Result<i32> {
    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }
    let plans = build_plan(&rows);

    let archived = plans
        .iter()
        .filter(|plan| plan.conversation.archived)
        .count();
    let candidates = plans
        .iter()
        .filter(|plan| {
            matches!(plan.verdict, Verdict::Archive | Verdict::Delete)
                && !plan.conversation.archived
        })
        .collect::<Vec<_>>();
    let duplicate = candidates.iter().filter(|plan| plan.dupe.is_some()).count();
    let empty = candidates
        .iter()
        .filter(|plan| plan.dupe.is_none() && plan.conversation.turns == 0)
        .count();
    let one_shot = candidates.len() - duplicate - empty;
    let unknown = plans
        .iter()
        .filter(|plan| plan.verdict == Verdict::Unknown)
        .count();

    println!("índice      : {} conversas", plans.len());
    println!("arquivadas  : {archived}");
    println!("candidatas  : {}", candidates.len());
    println!("  duplicadas: {duplicate}");
    println!("  one-shot  : {one_shot}");
    println!("  vazias    : {empty}");
    if unknown > 0 {
        println!("sem conteúdo: {unknown} (rode: cg sync --deep)");
    }
    Ok(0)
}

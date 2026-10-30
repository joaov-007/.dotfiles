//! `cg organize`: move keeper chats into matching Projects.

use std::collections::HashMap;
use std::fmt::Write as _;

use chrono::Local;

use crate::api::{Project, create_project, list_projects, move_confirmed, set_project};
use crate::auth::authenticate;
use crate::cli::OrganizeArgs;
use crate::config::Paths;
use crate::error::{Error, Result};
use crate::journal::{self, Entry};
use crate::live;
use crate::lock::{self, RunLock};
use crate::model::ProjectId;
use crate::plan::{PlannedConversation, build_plan};
use crate::projects::{ProjectTarget, SkippedGroup, plan_projects, project_key};
use crate::store::Index;
use crate::text::truncate_chars;

/// Dry-run by default. `--yes` creates Projects, moves chats, journals every
/// change, and snapshots the index first.
// The command flow reads top to bottom: plan, show, create, move, report.
#[allow(clippy::too_many_lines)]
pub fn run(paths: &Paths, args: &OrganizeArgs) -> Result<i32> {
    let _lease: RunLock = lock::acquire(&paths.lock)?;

    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }

    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(args.sleep, live::RETRIES);
    let session = authenticate(&mut client, &args.auth, paths)?;
    let token = session.access_token;

    let projects = list_projects(&mut client, &base, &token)?;
    let aliases = parse_aliases(&args.map)?;
    let fallback = if args.no_fallback {
        None
    } else {
        Some(args.fallback.as_str())
    };

    let plans = build_plan(&rows);
    let (mut targets, skipped) = plan_projects(&plans, &projects, &aliases, args.min, fallback);
    let create_indices = targets
        .iter()
        .enumerate()
        .filter(|(_, target)| target.project_id.is_none())
        .map(|(index, _)| index)
        .collect::<Vec<_>>();
    let moves = targets
        .iter()
        .map(|target| {
            target
                .items
                .iter()
                .filter(|plan| needs_move(target, plan))
                .count()
        })
        .sum::<usize>();

    print_plan(
        &projects,
        &targets,
        &skipped,
        args.min,
        create_indices.len(),
        moves,
    );
    let created_count = create_indices.len();
    if moves == 0 {
        println!("\nnada a mover — os Projects já refletem o plano.");
        return Ok(0);
    }
    if !args.yes {
        println!("\ndry-run: nada foi enviado. aplicar com --yes");
        return Ok(0);
    }

    paths.ensure_state()?;
    let now = live::now_string();
    let path = journal::path_for(&paths.reports, "organize", Local::now());
    let mut journal = journal::create(&path)?;
    let backup = journal::snapshot_for(&paths.reports, "organize-backup", Local::now());
    index.snapshot(&backup)?;

    for index_of_target in create_indices {
        let name = targets[index_of_target].name.clone();
        let (status, id) = create_project(&mut client, &base, &token, &name)?;
        journal.append(&Entry::project(
            &name,
            id.as_ref().map(ProjectId::as_str),
            status,
            &now,
        ))?;
        let Some(id) = id else {
            if let Some(error) = live::abort_for(status) {
                println!(
                    "\nabortado: não criou o Project {name:?} (HTTP {status}).\nlog: {}",
                    journal.path().display()
                );
                return Err(error);
            }
            println!(
                "abortado: não criou o Project {name:?} (HTTP {status})\nlog: {}",
                journal.path().display()
            );
            return Ok(2);
        };
        println!("criado: {name} ({id})");
        targets[index_of_target].project_id = Some(id);
    }

    let limit = if args.limit == 0 { moves } else { args.limit };
    let queue = targets
        .iter()
        .enumerate()
        .flat_map(|(index, target)| target.items.iter().map(move |plan| (index, *plan)))
        .filter(|(index, plan)| needs_move(&targets[*index], plan))
        .take(limit)
        .collect::<Vec<_>>();

    let mut done = 0_usize;
    let mut failed = 0_usize;
    let mut gone = 0_usize;
    let total = queue.len();
    for (position, (index_of_target, plan)) in queue.iter().enumerate() {
        let target = &targets[*index_of_target];
        let row = &plan.conversation;
        let Some(target_id) = target.project_id.as_ref() else {
            failed += 1;
            println!("[{:>3}/{total}] projeto desconhecido", position + 1);
            continue;
        };
        if !row.id.is_writable() {
            failed += 1;
            println!("[{:>3}/{total}] id inválido, pulando", position + 1);
            continue;
        }

        let response = set_project(&mut client, &base, &token, &row.id, Some(target_id))?;
        if let Some(error) = live::abort_for(response.status) {
            println!(
                "\nabortado: HTTP {} — sessão inválida ou rate limit.\n\
                 movidas até aqui: {done}. log: {}",
                response.status,
                journal.path().display()
            );
            return Err(error);
        }
        let ok = move_confirmed(response.status, &response.body, Some(target_id));
        if response.status == 404 {
            gone += 1;
            index.mark_gone(&row.id)?;
        }
        journal.append(&Entry::moved(
            row.id.as_str(),
            row.project_id.as_deref(),
            Some(target_id.as_str()),
            Some(&target.name),
            response.status,
            ok,
            response.status == 404,
            &now,
        ))?;

        if ok {
            done += 1;
            index.set_project(&row.id, Some(target_id.as_str()))?;
            println!(
                "[{:>3}/{total}] ok       {:20} {}",
                position + 1,
                truncate_chars(&target.name, 20),
                truncate_chars(&row.title, 44)
            );
        } else if response.status == 404 {
            println!(
                "[{:>3}/{total}] sumiu    {}",
                position + 1,
                truncate_chars(&row.title, 44)
            );
        } else if (200..300).contains(&response.status) {
            failed += 1;
            println!(
                "[{:>3}/{total}] sem confirmação  {}",
                position + 1,
                truncate_chars(&row.title, 44)
            );
        } else {
            failed += 1;
            println!(
                "[{:>3}/{total}] HTTP {}  {}",
                position + 1,
                response.status,
                truncate_chars(&row.title, 44)
            );
        }
    }

    let mut summary = format!("movidas: {done} · falhas: {failed} · criadas: {created_count}");
    if gone > 0 {
        let _ = write!(summary, " · sumidas do site: {gone}");
    }
    println!("\n{summary}");
    println!("log      : {}", journal.path().display());
    println!("backup   : {}", backup.display());
    println!(
        "desfazer : cg unorganize --log {}",
        journal.path().display()
    );
    Ok(i32::from(failed != 0))
}

/// `--map CATEGORIA=PROJETO`, keyed the same way categories are.
fn parse_aliases(specs: &[String]) -> Result<HashMap<String, String>> {
    let mut aliases = HashMap::new();
    for spec in specs {
        let Some((category, name)) = spec.split_once('=') else {
            return Err(Error::usage(format!(
                "--map espera Categoria=Projeto, veio {spec:?}"
            )));
        };
        let name = name.trim();
        if category.trim().is_empty() || name.is_empty() {
            return Err(Error::usage(format!(
                "--map espera Categoria=Projeto, veio {spec:?}"
            )));
        }
        aliases.insert(project_key(category), name.to_owned());
    }
    Ok(aliases)
}

fn needs_move(target: &ProjectTarget<'_>, plan: &PlannedConversation) -> bool {
    match target.project_id.as_ref() {
        None => true,
        Some(id) => plan.conversation.project_id.as_deref() != Some(id.as_str()),
    }
}

fn print_plan(
    projects: &[Project],
    targets: &[ProjectTarget<'_>],
    skipped: &[SkippedGroup],
    minimum: usize,
    to_create: usize,
    moves: usize,
) {
    println!("projetos existentes: {}", projects.len());
    println!(
        "categorias: {} · a criar: {to_create} · movimentos: {moves}",
        targets.len()
    );
    for target in targets {
        let mark = if target.project_id.is_some() {
            "→"
        } else {
            "+"
        };
        println!(
            "  {mark} {:34} {:>3} chats  ({})",
            truncate_chars(&target.name, 34),
            target.items.len(),
            target.categories.join(", ")
        );
    }
    for group in skipped {
        println!(
            "  · {:34} {:>3} chats  ignorado (--min {minimum})",
            truncate_chars(&group.name, 34),
            group.count
        );
    }
}

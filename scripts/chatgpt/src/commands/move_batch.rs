//! `cg move`: move an explicit batch of chats to one Project.

use std::collections::HashSet;

use chrono::Local;

use crate::api::{Project, create_project, list_projects, move_confirmed, set_project};
use crate::auth::authenticate;
use crate::cli::MoveArgs;
use crate::config::Paths;
use crate::error::{Error, Result};
use crate::journal::{self, Entry};
use crate::live;
use crate::lock::{self, RunLock};
use crate::model::{ConversationId, ProjectId};
use crate::projects::project_key;
use crate::store::{Index, StoredConversation};
use crate::text::truncate_chars;

/// Filter by `--ids` and/or `--from`; refuse to move everything by accident.
// The command flow reads top to bottom: auth, select, show, apply, report.
#[allow(clippy::too_many_lines)]
pub fn run(paths: &Paths, args: &MoveArgs) -> Result<i32> {
    let _lease: RunLock = lock::acquire(&paths.lock)?;

    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(args.sleep, live::RETRIES);
    let session = authenticate(&mut client, &args.auth, paths)?;
    let token = session.access_token;

    let mut projects = list_projects(&mut client, &base, &token)?;
    let target = resolve_target(&mut client, &base, &token, &mut projects, args)?;
    let (from_pid, from_name, from_unassigned) = resolve_source(&projects, args)?;

    let wanted = args
        .ids
        .as_ref()
        .map(|path| live::read_ids(path))
        .transpose()?
        .map(|ids| ids.into_iter().collect::<HashSet<_>>());

    let index = Index::open(&paths.db)?;
    let rows = index.all_active()?;
    if rows.is_empty() {
        return Err(Error::EmptyIndex);
    }

    let targets = rows
        .iter()
        .filter(|row| {
            selected(
                row,
                wanted.as_ref(),
                from_pid.as_ref(),
                from_unassigned,
                &target,
            )
        })
        .collect::<Vec<_>>();
    if targets.is_empty() {
        println!("nada para mover com esses filtros.");
        return Ok(0);
    }

    let limit = if args.limit == 0 {
        targets.len()
    } else {
        args.limit
    };
    let batch = &targets[..limit.min(targets.len())];

    println!("destino  : {} ({})", target.name, target.id);
    if let Some(name) = &from_name {
        println!("origem   : {name}");
    } else if let Some(wanted) = &wanted {
        println!("filtro   : {} ids", wanted.len());
    } else {
        println!("filtro   : sem projeto / conforme filtros");
    }
    println!(
        "a mover  : {} (de {} candidatas)",
        batch.len(),
        targets.len()
    );
    for row in batch.iter().take(12) {
        println!(
            "  · {}  https://chatgpt.com/c/{}",
            truncate_chars(&row.title, 70),
            row.id
        );
    }
    if batch.len() > 12 {
        println!("  … e mais {}", batch.len() - 12);
    }

    if !args.yes {
        println!("\nsimulação: nada foi enviado. aplicar com --yes");
        return Ok(0);
    }

    paths.ensure_state()?;
    let now = live::now_string();
    let path = journal::path_for(&paths.reports, "move", Local::now());
    let mut journal = journal::create(&path)?;
    let backup = journal::snapshot_for(&paths.reports, "move-backup", Local::now());
    index.snapshot(&backup)?;

    let mut done = 0_usize;
    let mut failed = 0_usize;
    let total = batch.len();
    for (position, row) in batch.iter().enumerate() {
        if !row.id.is_writable() {
            failed += 1;
            println!("[{:>3}/{total}] id inválido  {}", position + 1, row.id);
            continue;
        }

        let response = set_project(&mut client, &base, &token, &row.id, Some(&target.id))?;
        if let Some(error) = live::abort_for(response.status) {
            println!(
                "\nabortado: HTTP {} — sessão inválida ou rate limit.\n\
                 movidas até aqui: {done}. log: {}",
                response.status,
                journal.path().display()
            );
            return Err(error);
        }
        let ok = move_confirmed(response.status, &response.body, Some(&target.id));
        journal.append(&Entry::Move {
            conv_id: row.id.to_string(),
            from: row.project_id.clone(),
            to: Some(target.id.to_string()),
            project: None,
            to_name: Some(target.name.clone()),
            from_name: from_name.clone(),
            status: response.status,
            ok,
            gone: false,
            at: now.clone(),
        })?;

        if ok {
            done += 1;
            index.set_project(&row.id, Some(target.id.as_str()))?;
            println!(
                "[{:>3}/{total}] ok       {}",
                position + 1,
                truncate_chars(&row.title, 64)
            );
        } else {
            failed += 1;
            println!(
                "[{:>3}/{total}] HTTP {}  {}",
                position + 1,
                response.status,
                truncate_chars(&row.title, 64)
            );
        }
    }

    println!("\nmovidas: {done} · falhas: {failed}");
    println!("log     : {}", journal.path().display());
    println!("backup  : {}", backup.display());
    println!("desfazer: cg unorganize --log {}", journal.path().display());
    Ok(i32::from(failed != 0))
}

fn resolve_target(
    client: &mut crate::http::HttpClient,
    base: &str,
    token: &str,
    projects: &mut Vec<Project>,
    args: &MoveArgs,
) -> Result<Project> {
    let key = project_key(&args.to);
    if let Some(found) = projects
        .iter()
        .find(|project| project_key(&project.name) == key)
    {
        return Ok(found.clone());
    }
    if args.create {
        let name = args.to.trim().to_owned();
        let (status, id) = create_project(client, base, token, &name)?;
        if let Some(error) = live::abort_for(status) {
            return Err(error);
        }
        let Some(id) = id else {
            return Err(Error::Invalid(format!(
                "não foi possível criar o projeto '{name}' (HTTP {status})"
            )));
        };
        println!("criado   : {name} ({id})");
        let project = Project { id, name };
        projects.push(project.clone());
        return Ok(project);
    }
    Err(Error::usage(format!(
        "projeto de destino '{}' não encontrado.\n  Veja com: cg projects\n  \
         Ou crie com: cg move --to '{}' --create ...",
        args.to, args.to
    )))
}

fn resolve_source(
    projects: &[Project],
    args: &MoveArgs,
) -> Result<(Option<ProjectId>, Option<String>, bool)> {
    let Some(raw) = args.from.as_deref() else {
        return Ok((None, None, false));
    };
    if live::is_unassigned(raw) {
        return Ok((None, Some("sem projeto".to_owned()), true));
    }
    let source = live::project_named(projects, raw)?;
    Ok((Some(source.id.clone()), Some(source.name.clone()), false))
}

fn selected(
    row: &StoredConversation,
    wanted: Option<&HashSet<ConversationId>>,
    from_pid: Option<&ProjectId>,
    from_unassigned: bool,
    target: &Project,
) -> bool {
    if let Some(wanted) = wanted
        && !wanted.contains(&row.id)
    {
        return false;
    }
    if from_unassigned {
        if row.project_id.is_some() {
            return false;
        }
    } else if let Some(pid) = from_pid {
        if row.project_id.as_deref() != Some(pid.as_str()) {
            return false;
        }
    } else if wanted.is_none() {
        // No source and no explicit ids: be conservative, move nothing.
        return false;
    }
    row.project_id.as_deref() != Some(target.id.as_str())
}

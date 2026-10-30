//! `cg unorganize`: replay an organize/move journal backwards.

use crate::api::{move_confirmed, set_project};
use crate::auth::authenticate;
use crate::cli::UnorganizeArgs;
use crate::config::Paths;
use crate::error::Result;
use crate::journal::{self, Entry};
use crate::live;
use crate::lock::{self, RunLock};
use crate::model::ConversationId;
use crate::store::Index;

/// Every successful move goes back to its recorded `from`, newest journal last.
pub fn run(paths: &Paths, args: &UnorganizeArgs) -> Result<i32> {
    let _lease: RunLock = lock::acquire(&paths.lock)?;

    let entries = journal::read(&args.log)?;
    let moves = entries
        .iter()
        .filter(|entry| matches!(entry, Entry::Move { ok: true, .. }))
        .collect::<Vec<_>>();
    if moves.is_empty() {
        println!("nada para desfazer nesse log.");
        return Ok(0);
    }

    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(args.sleep, live::RETRIES);
    let session = authenticate(&mut client, &args.auth, paths)?;
    let token = session.access_token;
    let index = Index::open(&paths.db)?;

    let mut done = 0_usize;
    let total = moves.len();
    for (position, entry) in moves.iter().enumerate() {
        let Entry::Move {
            conv_id,
            from,
            project,
            ..
        } = entry
        else {
            continue;
        };
        let Some(id) = ConversationId::parse(conv_id) else {
            println!("[{:>3}/{total}] id inválido  {conv_id}", position + 1);
            continue;
        };
        let from_id = match live::parse_project_id(from.as_deref()) {
            Ok(from_id) => from_id,
            Err(error) => {
                println!("[{:>3}/{total}] {error}", position + 1);
                continue;
            }
        };

        let response = set_project(&mut client, &base, &token, &id, from_id.as_ref())?;
        if let Some(error) = live::abort_for(response.status) {
            println!(
                "\nabortado: HTTP {} — sessão inválida ou rate limit.",
                response.status
            );
            return Err(error);
        }
        if move_confirmed(response.status, &response.body, from_id.as_ref()) {
            done += 1;
            index.set_project(&id, from_id.as_ref().map(crate::model::ProjectId::as_str))?;
            println!(
                "[{:>3}/{total}] devolvida  {}",
                position + 1,
                project.as_deref().unwrap_or("")
            );
        } else {
            println!(
                "[{:>3}/{total}] HTTP {}  {conv_id}",
                position + 1,
                response.status
            );
        }
    }

    println!("\ndevolvidas: {done}/{total}");
    let created = entries
        .iter()
        .filter_map(|entry| match entry {
            Entry::Project {
                name, project_id, ..
            } => Some((name, project_id)),
            _ => None,
        })
        .collect::<Vec<_>>();
    if !created.is_empty() {
        println!("Projects criados por esta execução continuam existindo (nada é apagado):");
        for (name, project_id) in created {
            println!("  {name}  {}", project_id.as_deref().unwrap_or(""));
        }
    }
    Ok(0)
}

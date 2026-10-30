//! `cg unarchive`: restore conversations hidden by `cg archive`.

use crate::api::set_archived;
use crate::auth::authenticate;
use crate::cli::UnarchiveArgs;
use crate::config::Paths;
use crate::error::{Error, Result};
use crate::journal::{self, Entry};
use crate::live;
use crate::lock::{self, RunLock};
use crate::model::ConversationId;
use crate::store::Index;

/// Restore exactly one journal, or everything the index believes is archived.
pub fn run(paths: &Paths, args: &UnarchiveArgs) -> Result<i32> {
    let _lease: RunLock = lock::acquire(&paths.lock)?;

    let index = Index::open(&paths.db)?;
    let ids = if let Some(log) = &args.log {
        journal::read(log)?
            .iter()
            .filter_map(|entry| match entry {
                Entry::Archive {
                    conv_id, ok: true, ..
                } => ConversationId::parse(conv_id),
                _ => None,
            })
            .collect::<Vec<_>>()
    } else if args.all {
        index.archived_ids()?
    } else {
        return Err(Error::usage("passe --log <archive-*.jsonl> ou --all"));
    };

    if ids.is_empty() {
        println!("nada para desarquivar.");
        return Ok(0);
    }

    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(args.sleep, live::RETRIES);
    let session = authenticate(&mut client, &args.auth, paths)?;
    let token = session.access_token;

    let mut done = 0_usize;
    let total = ids.len();
    for (position, id) in ids.iter().enumerate() {
        let response = set_archived(&mut client, &base, &token, id, false)?;
        if let Some(error) = live::abort_for(response.status) {
            println!(
                "\nabortado: HTTP {} — sessão inválida ou rate limit.",
                response.status
            );
            return Err(error);
        }
        if (200..300).contains(&response.status) {
            done += 1;
            index.set_archived(id, false)?;
            println!("[{:>3}/{total}] restaurada  {id}", position + 1);
        } else {
            println!(
                "[{:>3}/{total}] HTTP {}  {id}",
                position + 1,
                response.status
            );
        }
    }
    println!("\nrestauradas: {done}/{total}");
    Ok(i32::from(done != total))
}

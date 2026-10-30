//! `cg sync`: index the account through the sidebar endpoints.

use crate::api::conversations_page;
use crate::auth::authenticate;
use crate::cli::SyncArgs;
use crate::config::Paths;
use crate::error::Result;
use crate::live;
use crate::model::parse_conversation;
use crate::store::Index;

const PAGE: usize = 100;

/// The list gives id/title/dates; `--deep` fetches each body, resumably.
// The command flow reads top to bottom: list, reconcile, fetch bodies.
#[allow(clippy::too_many_lines, clippy::cast_precision_loss)]
pub fn run(paths: &Paths, args: &SyncArgs) -> Result<i32> {
    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(args.sleep, args.max_retries);
    let session = authenticate(&mut client, &args.auth, paths)?;
    let token = session.access_token;

    paths.ensure_state()?;
    let index = Index::open(&paths.db)?;
    let now = live::now_string();
    let source = format!("api:{base}");

    let mut offset = 0_usize;
    let mut total;
    let mut new = 0_usize;
    let mut updated = 0_usize;

    loop {
        let page = conversations_page(&mut client, &base, &token, offset, PAGE)?;
        total = page.total;
        if page.items.is_empty() {
            break;
        }
        let seen = page.items.len();
        for raw in &page.items {
            let Some(conversation) = parse_conversation(raw) else {
                continue;
            };
            if index.record(&conversation, &source, &now, None)? {
                new += 1;
            } else {
                updated += 1;
            }
        }
        offset += seen;
        if offset >= total {
            break;
        }
    }

    let indexed = index.count()?;
    println!("conta   : {}", session.email.as_deref().unwrap_or("?"));
    println!("listadas: {offset} de {total}");
    println!("novas   : {new} · atualizadas: {updated}");
    println!("índice  : {indexed} conversas");

    let (_, missing) = index.missing_content(0)?;
    if !args.deep {
        if missing > 0 {
            println!("conteúdo: {missing} conversas sem corpo (rode: cg sync --deep)");
        } else {
            println!("\npróximo passo: cg plan");
        }
        return Ok(0);
    }

    let (pending, _) = index.missing_content(args.limit)?;
    if pending.is_empty() {
        println!("\nconteúdo: tudo já indexado — rode `cg plan`.");
        return Ok(0);
    }

    client.set_sleep(args.sleep);
    let estimate = (pending.len() as f64 * (args.sleep + 0.6) / 60.0).round();
    println!(
        "\nbaixando conteúdo de {} conversas (~{estimate:.0} min)",
        pending.len()
    );

    let mut done = 0_usize;
    let mut failed = 0_usize;
    let mut gone = 0_usize;
    let count = pending.len();
    for (position, id) in pending.iter().enumerate() {
        let response = crate::api::conversation(&mut client, &base, &token, id)?;
        if let Some(error) = live::abort_for(response.status) {
            println!(
                "\nabortado: HTTP {} com {done} conversas baixadas.",
                response.status
            );
            println!("progresso salvo; rode o mesmo comando para retomar daqui.");
            return Err(error);
        }
        match response.status {
            404 => {
                gone += 1;
                index.mark_gone(id)?;
            }
            200 => {
                let Ok(raw) = serde_json::from_str(&response.body) else {
                    failed += 1;
                    continue;
                };
                let Some(conversation) = parse_conversation(&raw) else {
                    gone += 1;
                    continue;
                };
                index.record(&conversation, &source, &now, Some(true))?;
                done += 1;
            }
            _ => failed += 1,
        }
        let position = position + 1;
        if position % 20 == 0 || position == count {
            println!("  {position}/{count} · {done} ok · {failed} erros");
        }
    }

    println!("conteúdo: {done} baixadas · {failed} falhas · {gone} sumidas");
    let (_, left) = index.missing_content(0)?;
    if left > 0 {
        println!("faltam  : {left} (rode o mesmo comando para continuar)");
    }
    println!("\npróximo passo: cg plan");
    Ok(i32::from(failed != 0))
}

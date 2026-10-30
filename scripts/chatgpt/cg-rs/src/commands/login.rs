//! `cg login`: validate a cookie and save it for every later command.

use std::io::{IsTerminal, Read};

use crate::auth::{build_cookie, open_session, save_cookie};
use crate::cli::LoginArgs;
use crate::config::Paths;
use crate::error::{Error, Result};
use crate::http::validate_url;
use crate::live;

/// Read the cookie from a flag, a file, or stdin, prove it works, then store it
/// with mode 0600. Browser keyring harvesting is deliberately not here yet.
pub fn run(paths: &Paths, args: &LoginArgs) -> Result<()> {
    let base = args.auth.base_url.trim_end_matches('/').to_owned();
    validate_url(&base)?;

    let (origin, cookie) = if let Some(raw) = args.auth.effective_cookie() {
        ("--cookie".to_owned(), build_cookie(&raw)?)
    } else if let Some(file) = &args.auth.cookie_file {
        let raw = std::fs::read_to_string(file).map_err(|error| {
            Error::usage(format!(
                "arquivo de cookie não encontrado: {} ({error})",
                file.display()
            ))
        })?;
        (file.to_string_lossy().into_owned(), build_cookie(&raw)?)
    } else {
        ("stdin".to_owned(), read_stdin()?)
    };

    let mut client = live::client(1.0, live::RETRIES);
    let session = open_session(&mut client, &base, &cookie)?;

    let target = args.save.clone().unwrap_or_else(|| paths.session.clone());
    save_cookie(&cookie, &target)?;

    let chunks = cookie.matches("__Secure-next-auth.session-token.").count();
    let values = cookie.matches('=').count();
    println!("origem  : {origin}");
    println!(
        "cookies : {values} valores · sessão em {} parte(s)",
        chunks.max(1)
    );
    println!("conta   : {}", session.email.as_deref().unwrap_or("?"));
    println!("plano   : {}", session.plan.as_deref().unwrap_or("?"));
    println!("expira  : {}", session.expires.as_deref().unwrap_or("?"));
    println!("salvo   : {} (600)", target.display());
    println!("\npronto — os comandos online usam esse arquivo sozinhos.");
    Ok(())
}

fn read_stdin() -> Result<String> {
    let stdin = std::io::stdin();
    if stdin.is_terminal() {
        eprintln!(
            "cole o cabeçalho `cookie:` do DevTools e pressione Ctrl-D \
             (ou use --cookie-file)"
        );
    }
    let mut raw = String::new();
    stdin
        .lock()
        .read_to_string(&mut raw)
        .map_err(|error| Error::usage(format!("não foi possível ler a entrada: {error}")))?;
    if raw.trim().is_empty() {
        return Err(Error::usage(
            "nenhum cookie informado.\n  Passe --cookie-file, --cookie, ou cole via \
             pipe:\n  pbpaste | cg login",
        ));
    }
    build_cookie(&raw)
}

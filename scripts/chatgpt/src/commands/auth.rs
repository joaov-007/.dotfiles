//! `cg auth`: check that the saved session still works.

use crate::auth::authenticate;
use crate::cli::AuthArgs;
use crate::config::Paths;
use crate::error::Result;
use crate::live;

/// One read-only request; prints account, plan, and expiry.
pub fn run(paths: &Paths, args: &AuthArgs) -> Result<()> {
    let base = args.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(1.0, live::RETRIES);
    let session = authenticate(&mut client, args, paths)?;

    println!("conta   : {}", session.email.as_deref().unwrap_or("?"));
    println!("plano   : {}", session.plan.as_deref().unwrap_or("?"));
    println!("expira  : {}", session.expires.as_deref().unwrap_or("?"));
    println!("base    : {base}");
    println!("\nsessão válida. `cg archive` pode rodar.");
    Ok(())
}

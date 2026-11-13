//! `cg logout`: forget the session everywhere it was stored.

use crate::auth::clear_cookie;
use crate::cli::AuthArgs;
use crate::config::Paths;
use crate::error::Result;
use crate::secret;

/// Remove the keyring entry and, if it exists, the 0600 fallback file.
pub fn run(paths: &Paths, auth: &AuthArgs) -> Result<()> {
    let cleared = clear_cookie(auth, paths)?;

    if cleared.keyring {
        let account = secret::account_for(&auth.base_url);
        println!("chaveiro: {} removido", secret::label(&account));
    }
    if let Some(path) = &cleared.file {
        println!("arquivo : {} apagado", path.display());
    }

    if !cleared.keyring && cleared.file.is_none() {
        println!("nada para remover — nenhuma sessão salva.");
    } else {
        println!("\nsessão esquecida. `cg login` guarda uma nova.");
    }
    Ok(())
}

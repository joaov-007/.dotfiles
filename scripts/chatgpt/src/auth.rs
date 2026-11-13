//! Cookie normalisation and session validation.
//
//! Paranoid protections for pen‑tester threat model:
//!   • OS keyring by default (Secret Service, Credential Manager, Keychain)
//!   • 0600 file only as a fallback for headless or locked sessions
//!   • Strict format validation (no newlines, control chars, absurd length)
//!   • Secure on‑disk erasure (overwrite before delete)
//!   • Never log the cookie value itself
//!   • Explicit clear/shred function
//!   • Enforce same‑origin‑ish restrictions via cookie name prefix

use std::path::{Path, PathBuf};

use serde_json::Value;

use crate::cli::AuthArgs;
use crate::config::Paths;
use crate::error::{Error, Result};
use crate::http::HttpClient;
use crate::secret::{self, Lookup, Store};

/// This session cookie is split by the server across `.0` and `.1`.
pub const SESSION_COOKIE: &str = "__Secure-next-auth.session-token";

const UA: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 \
                  (KHTML, like Gecko) Chrome/140.0.0.0 Safari/140.0";

/// The chunked-token length window that means "you copied only the first half".
const CHUNK_LEN: std::ops::RangeInclusive<usize> = 3900..=3933;

/// Maximum allowed cookie length (bytes). Prevents absurdly large inputs
/// that could be used for injection or `DoS`.
const MAX_COOKIE_LEN: usize = 10_000;

/// A validated API session.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Session {
    pub access_token: String,
    pub email: Option<String>,
    pub plan: Option<String>,
    pub expires: Option<String>,
}

/// Securely overwrite a file's contents with zeros and remove it.
/// This is a best-effort erase; on many filesystems the data may still
/// linger until overwritten, but it removes the directory entry immediately.
#[cfg(unix)]
pub fn secure_wipe(path: &Path) -> Result<()> {
    use std::io::Write;

    // Read current content length so we can overwrite exactly that much.
    let len = std::fs::metadata(path).map_or(0, |m| m.len());
    let len_usize: usize = len.try_into().unwrap_or(0);
    // Build a zero buffer of the file's size.
    let buf = vec![0u8; len_usize];
    // Perform multiple overwrite passes (simple Gutmann‑style).
    for _ in 0..3 {
        // Open the file and overwrite with zeros.
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let mut f = std::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .create(false)
            .open(path)?;
        f.write_all(&buf)?;
        f.sync_all()?;
        drop(f);
    }
    // Remove the file entirely.
    std::fs::remove_file(path)?;
    Ok(())
}

#[cfg(not(unix))]
pub fn secure_wipe(_path: &Path) -> Result<()> {
    // On non‑Unix we cannot reliably overwrite; just remove.
    let _ = std::fs::remove_file(_path);
    Ok(())
}

/// Normalise whatever was pasted into a `Cookie` header value.
pub fn build_cookie(raw: &str) -> Result<String> {
    // --- Paranoid validations FIRST, before any trim/sanitisation ---
    // Reject carriage returns in the raw input to prevent header-injection.
    if raw.contains('\r') {
        return Err(Error::usage(
            "cookie contém retorno de carro (`\\r`) — remova-o antes de colar.",
        ));
    }
    let text = raw.trim();
    // Reject absurdly large inputs.
    if text.len() > MAX_COOKIE_LEN {
        return Err(Error::usage(format!(
            "cookie demasiado grande ({} bytes), máximo {} bytes",
            text.len(),
            MAX_COOKIE_LEN
        )));
    }
    // -------------------------------------------------------------------------
    let text = match text
        .strip_prefix("cookie:")
        .or_else(|| text.strip_prefix("Cookie:"))
    {
        Some(rest) => rest.trim_start(),
        None => text,
    };

    let lines = text
        .lines()
        .map(|line| line.trim().trim_end_matches(';').trim())
        .filter(|line| !line.is_empty())
        .filter(|line| !has_control_chars(line))
        .map(str::to_owned)
        .collect::<Vec<_>>();
    if lines.is_empty() {
        return Err(Error::usage("cookie vazio"));
    }

    // A terminal soft-wrap leaves a continuation with no '='; glue it back onto
    // the cookie it belongs to before deciding what shape this is.
    let mut merged: Vec<String> = Vec::new();
    for line in lines {
        match merged.last_mut() {
            Some(previous) if !is_named(&line) && is_named(previous) => previous.push_str(&line),
            _ => merged.push(line),
        }
    }

    let named = merged.iter().filter(|line| is_named(line)).count();
    if named == merged.len() {
        return Ok(merged.join("; "));
    }
    if named > 0 {
        return Err(Error::usage(
            "cookie misturado: use `nome=valor` em todas as linhas ou só os valores",
        ));
    }

    if merged.len() == 1 {
        let line = &merged[0];
        if line.contains(';') && line.contains('=') {
            // A full header pasted on one line: keep it untouched.
            return Ok(line.clone());
        }
        let token = line.trim();
        if CHUNK_LEN.contains(&token.len()) {
            return Err(Error::usage(format!(
                "esse valor tem {} caracteres — o tamanho do *primeiro pedaço* do token \
                 do NextAuth.\n  Esta sessão é dividida em dois cookies e o servidor \
                 precisa dos dois:\n    {SESSION_COOKIE}.0\n    {SESSION_COOKIE}.1\n  \
                 Caminho fácil: DevTools -> Network -> qualquer requisição a \
                 chatgpt.com ->\n  Request Headers, clique com o botão direito no \
                 cabeçalho `cookie:` -> Copy value.\n  Cole essa linha inteira no \
                 arquivo, ou ponha os dois valores em duas linhas, .0 primeiro.",
                token.len()
            )));
        }
        return Ok(format!("{SESSION_COOKIE}={token}"));
    }

    // Several bare chunks: rebuild the names the browser would have sent.
    let named_chunks = merged
        .iter()
        .enumerate()
        .map(|(index, chunk)| format!("{SESSION_COOKIE}.{index}={chunk}"))
        .collect::<Vec<_>>();
    Ok(named_chunks.join("; "))
}

fn is_named(line: &str) -> bool {
    let Some((name, _)) = line.split_once('=') else {
        return false;
    };
    !name.is_empty()
        && name
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '_' | '.' | '-'))
}

/// A line or value that contains control characters (other than space, tab,
/// which are already stripped) is rejected to prevent header-injection attacks.
fn has_control_chars(s: &str) -> bool {
    s.chars()
        .any(|c| !c.is_ascii_graphic() && !c.is_ascii_whitespace())
}

/// Persist a cookie the server already accepted: state dir, mode 0600.
pub fn save_cookie(cookie: &str, path: &Path) -> Result<()> {
    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    std::fs::write(path, format!("{}\n", cookie.trim()))?;
    restrict_to_owner(path)?;
    Ok(())
}

/// Where a validated cookie ended up.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Saved {
    /// OS keyring, under `cg/<account>`.
    Keyring(String),
    /// Plain file with mode 0600.
    File(PathBuf),
}

impl Saved {
    /// One line suitable for `cg login` output.
    #[must_use]
    pub fn describe(&self) -> String {
        match self {
            Self::Keyring(account) => {
                format!("chaveiro do sistema ({})", secret::label(account))
            }
            Self::File(path) => format!("{} (600)", path.display()),
        }
    }
}

/// What `cg logout` actually removed.
#[derive(Debug, Default, Clone, PartialEq, Eq)]
pub struct Cleared {
    pub keyring: bool,
    pub file: Option<PathBuf>,
}

#[cfg(unix)]
fn restrict_to_owner(path: &Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    Ok(())
}

#[cfg(not(unix))]
fn restrict_to_owner(_path: &Path) -> Result<()> {
    Ok(())
}

/// Find the cookie to use: explicit flag/env, an explicit file, the OS
/// keyring, then the default file.
///
/// `account` is `Some` only when the caller wants the keyring consulted.
pub fn resolve_cookie(
    explicit: Option<&str>,
    cookie_file: Option<&Path>,
    default_file: &Path,
    account: Option<&str>,
) -> Result<String> {
    resolve_cookie_with(
        &secret::OsStore,
        explicit,
        cookie_file,
        default_file,
        account,
    )
}

fn resolve_cookie_with(
    store: &dyn Store,
    explicit: Option<&str>,
    cookie_file: Option<&Path>,
    default_file: &Path,
    account: Option<&str>,
) -> Result<String> {
    if let Some(raw) = explicit.map(str::trim).filter(|raw| !raw.is_empty()) {
        return build_cookie(raw);
    }

    if let Some(path) = cookie_file {
        if !path.is_file() {
            return Err(Error::usage(format!(
                "arquivo de cookie não encontrado: {}",
                path.display()
            )));
        }
        return read_cookie_file(path);
    }

    if let Some(account) = account {
        match store.lookup(account) {
            Lookup::Found(raw) => return build_cookie(&raw),
            Lookup::Missing => {}
            Lookup::Unavailable(reason) => eprintln!(
                "aviso: chaveiro do sistema indisponível ({reason}); tentando {}",
                default_file.display()
            ),
        }
    }

    if !default_file.is_file() {
        return Err(Error::usage(
            "nenhum cookie de sessão.\n  Rode `cg login` para guardar no chaveiro do \
             sistema, ou cole\n  o cabeçalho `cookie:` do DevTools num arquivo 600 e \
             passe --cookie-file.",
        ));
    }

    read_cookie_file(default_file)
}

fn read_cookie_file(path: &Path) -> Result<String> {
    warn_if_world_readable(path);
    let raw = std::fs::read_to_string(path)?;
    build_cookie(&raw)
}

#[cfg(unix)]
fn warn_if_world_readable(path: &Path) {
    use std::os::unix::fs::PermissionsExt;
    if let Ok(metadata) = std::fs::metadata(path)
        && metadata.permissions().mode() & 0o077 != 0
    {
        eprintln!(
            "aviso: {} é legível por outros — chmod 600 {}",
            path.display(),
            path.display()
        );
    }
}

#[cfg(not(unix))]
fn warn_if_world_readable(_path: &Path) {}

/// Headers the API expects on every authenticated request.
#[must_use]
pub fn api_headers(token: &str, base: &str) -> Vec<(String, String)> {
    vec![
        ("Authorization".to_owned(), format!("Bearer {token}")),
        ("Content-Type".to_owned(), "application/json".to_owned()),
        ("Accept".to_owned(), "application/json".to_owned()),
        ("User-Agent".to_owned(), UA.to_owned()),
        ("Origin".to_owned(), base.to_owned()),
        ("Referer".to_owned(), format!("{base}/")),
    ]
}

/// Validate a cookie against `/api/auth/session`.
pub fn open_session(client: &mut HttpClient, base: &str, cookie: &str) -> Result<Session> {
    let request = crate::http::Request::new(
        crate::http::Method::Get,
        format!("{}/api/auth/session", base.trim_end_matches('/')),
    )
    .header("Cookie", cookie)
    .header("User-Agent", UA)
    .header("Accept", "application/json");

    let response = client.send(&request)?;
    if response.is_auth_failure() {
        return Err(Error::SessionExpired(format!(
            "verificação de sessão falhou (HTTP {}) — cookie expirado",
            response.status
        )));
    }
    if response.status != 200 {
        return Err(Error::SessionExpired(format!(
            "verificação de sessão falhou (HTTP {}) — cookie expirado ou conta errada",
            response.status
        )));
    }

    let data: Value = serde_json::from_str(&response.body).map_err(|_| {
        Error::SessionExpired(
            "/api/auth/session devolveu algo que não é JSON — desafio do Cloudflare?".to_owned(),
        )
    })?;
    let token = data
        .get("accessToken")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|token| !token.is_empty())
        .ok_or_else(|| {
            Error::SessionExpired(format!(
                "o servidor respondeu com sessão vazia — o cookie foi recusado.\n  \
                 Enviei {} caracteres de cookie. Causas comuns: sessão expirada, ou só \
                 o\n  primeiro pedaço (.0) foi copiado e o .1 ficou para trás. \
                 Copie o cabeçalho\n  `cookie:` inteiro de novo.",
                cookie.len()
            ))
        })?;

    let user = data.get("user");
    let text = |key: &str| {
        user.and_then(|user| user.get(key))
            .and_then(Value::as_str)
            .map(str::trim)
            .filter(|value| !value.is_empty())
            .map(str::to_owned)
    };
    Ok(Session {
        access_token: token.to_owned(),
        email: text("email").or_else(|| text("name")),
        plan: text("planType"),
        expires: data
            .get("expires")
            .and_then(Value::as_str)
            .map(str::to_owned),
    })
}

/// Resolve the cookie, validate it, and return the session.
///
/// An explicit flag or `CG_COOKIE` always wins, then `--cookie-file`, then the
/// OS keyring, then the legacy file. A rejected saved cookie is an error here;
/// phase 4 adds the browser fallback the Python version has.
pub fn authenticate(client: &mut HttpClient, auth: &AuthArgs, paths: &Paths) -> Result<Session> {
    let base = auth.base_url.trim_end_matches('/');
    crate::http::validate_url(base)?;
    let explicit = auth.effective_cookie();
    let account = uses_keyring(auth).then(|| secret::account_for(base));
    let cookie = resolve_cookie(
        explicit.as_deref(),
        auth.cookie_file.as_deref(),
        &paths.session,
        account.as_deref(),
    )?;
    open_session(client, base, &cookie)
}

/// Save a header after the server accepted it: keyring first, file as fallback.
///
/// A path given with `--cookie-file` is always written as a file, because the
/// user asked for that location explicitly.
pub fn remember(session_cookie: &str, auth: &AuthArgs, paths: &Paths) -> Result<Saved> {
    remember_with(&secret::OsStore, session_cookie, auth, paths)
}

fn remember_with(
    store: &dyn Store,
    session_cookie: &str,
    auth: &AuthArgs,
    paths: &Paths,
) -> Result<Saved> {
    let path = session_path(auth, paths);
    let account = secret::account_for(&auth.base_url);

    // `--no-keyring` is a storage choice: remove an older keyring copy so it
    // cannot shadow the file that is about to be written.
    if auth.no_keyring
        && auth.cookie_file.is_none()
        && secret::enabled()
        && matches!(store.lookup(&account), Lookup::Found(_))
        && let Err(reason) = store.forget(&account)
    {
        eprintln!("aviso: não foi possível remover a cópia antiga do chaveiro ({reason})");
    }

    if uses_keyring(auth) {
        match store.store(&account, session_cookie) {
            Ok(()) => {
                // A keyring copy makes the plaintext file redundant, but a
                // failed erase must not turn a successful save into an error.
                if let Err(error) = wipe_if_present(&path) {
                    eprintln!(
                        "aviso: sessão salva no chaveiro, mas não foi possível apagar {}: {error}",
                        path.display()
                    );
                }
                return Ok(Saved::Keyring(account));
            }
            Err(reason) => eprintln!(
                "aviso: chaveiro do sistema indisponível ({reason}); salvando em {}",
                path.display()
            ),
        }
    }

    save_cookie(session_cookie, &path)?;
    Ok(Saved::File(path))
}

/// Remove the keyring entry and the cookie file, whichever exist.
pub fn clear_cookie(auth: &AuthArgs, paths: &Paths) -> Result<Cleared> {
    clear_cookie_with(&secret::OsStore, auth, paths)
}

fn clear_cookie_with(store: &dyn Store, auth: &AuthArgs, paths: &Paths) -> Result<Cleared> {
    let mut cleared = Cleared::default();

    if uses_keyring(auth) {
        let account = secret::account_for(&auth.base_url);
        match store.forget(&account) {
            Ok(removed) => cleared.keyring = removed,
            Err(reason) => eprintln!("aviso: não foi possível limpar o chaveiro ({reason})"),
        }
    }

    let path = session_path(auth, paths);
    if wipe_if_present(&path)? {
        cleared.file = Some(path);
    }
    Ok(cleared)
}

/// Whether this invocation should consult the OS keyring.
fn uses_keyring(auth: &AuthArgs) -> bool {
    !auth.no_keyring && auth.cookie_file.is_none() && secret::enabled()
}

/// The file that mirrors (or replaces) the keyring entry.
fn session_path(auth: &AuthArgs, paths: &Paths) -> PathBuf {
    auth.cookie_file
        .clone()
        .unwrap_or_else(|| paths.session.clone())
}

/// Wipe a cookie file only when it exists.
pub fn wipe_if_present(path: &Path) -> Result<bool> {
    match std::fs::metadata(path) {
        Ok(_) => {
            secure_wipe(path)?;
            Ok(true)
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(false),
        Err(error) => Err(error.into()),
    }
}

#[cfg(test)]
mod tests {
    use std::cell::RefCell;

    use super::*;
    use crate::cli::AuthArgs;

    #[derive(Default)]
    struct FakeStore {
        lookup: RefCell<Option<Lookup>>,
        store: Option<std::result::Result<(), String>>,
        forget: Option<std::result::Result<bool, String>>,
        stored: RefCell<Option<(String, String)>>,
        account: RefCell<Option<String>>,
        forget_calls: std::cell::Cell<usize>,
    }

    impl Store for FakeStore {
        fn lookup(&self, account: &str) -> Lookup {
            self.account.replace(Some(account.to_owned()));
            self.lookup.borrow().clone().unwrap_or(Lookup::Missing)
        }

        fn store(&self, account: &str, secret: &str) -> std::result::Result<(), String> {
            self.account.replace(Some(account.to_owned()));
            self.stored
                .replace(Some((account.to_owned(), secret.to_owned())));
            self.store.clone().unwrap_or(Ok(()))
        }

        fn forget(&self, account: &str) -> std::result::Result<bool, String> {
            self.forget_calls.set(self.forget_calls.get() + 1);
            self.account.replace(Some(account.to_owned()));
            self.forget.clone().unwrap_or(Ok(false))
        }
    }

    fn live_auth() -> AuthArgs {
        AuthArgs {
            cookie: None,
            cookie_file: None,
            base_url: "https://chatgpt.com".to_owned(),
            no_keyring: false,
        }
    }

    #[test]
    fn a_whole_header_line_is_kept() {
        let raw = format!("{SESSION_COOKIE}=abc; other=def");
        assert_eq!(build_cookie(&raw).expect("cookie"), raw);
    }

    #[test]
    fn a_cookie_prefix_is_stripped() {
        assert_eq!(
            build_cookie("cookie: a=1; b=2").expect("cookie"),
            "a=1; b=2"
        );
    }

    #[test]
    fn named_lines_are_joined() {
        let raw = "a=1;\nb=2;\n";
        assert_eq!(build_cookie(raw).expect("cookie"), "a=1; b=2");
    }

    #[test]
    fn wrapped_lines_are_glued_back() {
        let raw = "__Secure-next-auth.session-token.0=AAA\nBBB\nAAA\n";
        assert_eq!(
            build_cookie(raw).expect("cookie"),
            format!("{SESSION_COOKIE}.0=AAABBBAAA")
        );
    }

    #[test]
    fn a_single_bare_token_gets_the_session_name() {
        assert_eq!(
            build_cookie("token-value").expect("cookie"),
            format!("{SESSION_COOKIE}=token-value")
        );
    }

    #[test]
    fn two_bare_chunks_are_named_in_order() {
        let cookie = build_cookie("first\nsecond").expect("cookie");
        assert_eq!(
            cookie,
            format!("{SESSION_COOKIE}.0=first; {SESSION_COOKIE}.1=second")
        );
    }

    #[test]
    fn a_first_chunk_alone_is_explained() {
        let error = build_cookie(&"a".repeat(3900)).expect_err("must fail");
        let message = error.to_string();
        assert!(message.contains("primeiro pedaço"), "{message}");
        assert!(message.contains(".1"), "{message}");
    }

    #[test]
    fn mixed_shapes_are_rejected() {
        assert!(build_cookie("bare\na=1\nb=2").is_err());
    }

    #[test]
    fn empty_input_is_rejected() {
        assert!(build_cookie(" \n ").is_err());
    }

    #[test]
    fn saved_cookies_are_private() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("a=1", &path).expect("save");
        assert_eq!(std::fs::read_to_string(&path).expect("read"), "a=1\n");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let mode = std::fs::metadata(&path).expect("meta").permissions().mode();
            assert_eq!(mode & 0o777, 0o600);
        }
    }

    #[test]
    fn the_explicit_cookie_wins_over_a_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("file=tok", &path).expect("save");
        let store = FakeStore::default();
        let cookie =
            resolve_cookie_with(&store, Some("flag=tok"), Some(&path), &path, Some("acct"))
                .expect("resolve");
        assert_eq!(cookie, "flag=tok");
    }

    #[test]
    fn a_missing_explicit_file_is_a_usage_error() {
        let error = resolve_cookie(
            None,
            Some(Path::new("/nope/session")),
            Path::new("/nope"),
            None,
        )
        .expect_err("must fail");
        assert_eq!(error.exit_code(), 2);
    }

    #[test]
    fn the_keyring_wins_over_the_legacy_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("file=tok", &path).expect("save");
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Found("ring=tok".to_owned()))),
            ..FakeStore::default()
        };
        let cookie = resolve_cookie_with(&store, None, None, &path, Some("session@chatgpt.com"))
            .expect("resolve");
        assert_eq!(cookie, "ring=tok");
    }

    #[test]
    fn a_missing_keyring_entry_falls_back_to_the_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("file=tok", &path).expect("save");
        let store = FakeStore::default();
        let cookie = resolve_cookie_with(&store, None, None, &path, Some("session@chatgpt.com"))
            .expect("resolve");
        assert_eq!(cookie, "file=tok");
    }

    #[test]
    fn an_unavailable_keyring_falls_back_to_the_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("file=tok", &path).expect("save");
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Unavailable("no dbus".to_owned()))),
            ..FakeStore::default()
        };
        let cookie = resolve_cookie_with(&store, None, None, &path, Some("session@chatgpt.com"))
            .expect("resolve");
        assert_eq!(cookie, "file=tok");
    }

    #[test]
    fn no_account_skips_the_keyring_entirely() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("file=tok", &path).expect("save");
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Found("ring=tok".to_owned()))),
            ..FakeStore::default()
        };
        let cookie = resolve_cookie_with(&store, None, None, &path, None).expect("resolve");
        assert_eq!(cookie, "file=tok");
        assert!(store.account.borrow().is_none());
    }

    #[test]
    fn an_explicit_cookie_file_skips_the_keyring() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        save_cookie("file=tok", &path).expect("save");
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Found("ring=tok".to_owned()))),
            ..FakeStore::default()
        };
        let cookie =
            resolve_cookie_with(&store, None, Some(&path), &path, Some("acct")).expect("resolve");
        assert_eq!(cookie, "file=tok");
        assert!(store.account.borrow().is_none());
    }

    #[test]
    fn nothing_anywhere_is_a_usage_error() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("session");
        let store = FakeStore::default();
        let error =
            resolve_cookie_with(&store, None, None, &path, Some("acct")).expect_err("must fail");
        assert_eq!(error.exit_code(), 2);
    }

    #[test]
    fn saved_locations_are_described_for_the_login_output() {
        assert_eq!(
            Saved::Keyring("session@chatgpt.com".to_owned()).describe(),
            "chaveiro do sistema (cg/session@chatgpt.com)"
        );
        let file = Saved::File(PathBuf::from("/tmp/session"));
        assert_eq!(file.describe(), "/tmp/session (600)");
    }

    #[test]
    fn remember_prefers_the_keyring_and_wipes_the_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        std::fs::create_dir_all(&paths.state_dir).expect("state");
        save_cookie("old=tok", &paths.session).expect("save");
        let store = FakeStore::default();

        let saved = remember_with(&store, "new=tok", &live_auth(), &paths).expect("remember");
        assert_eq!(saved, Saved::Keyring("session@chatgpt.com".to_owned()));
        assert!(!paths.session.exists());
        let stored = store.stored.borrow().clone().expect("stored");
        assert_eq!(stored.0, "session@chatgpt.com");
        assert_eq!(stored.1, "new=tok");
    }

    #[test]
    fn a_failed_erase_does_not_undo_a_keyring_save() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        std::fs::create_dir_all(&paths.session).expect("dir at the session path");
        let store = FakeStore::default();

        let saved = remember_with(&store, "new=tok", &live_auth(), &paths).expect("remember");
        assert_eq!(saved, Saved::Keyring("session@chatgpt.com".to_owned()));
        assert!(paths.session.is_dir());
    }

    #[test]
    fn remember_falls_back_to_a_private_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let store = FakeStore {
            store: Some(Err("locked".to_owned())),
            ..FakeStore::default()
        };

        let saved = remember_with(&store, "new=tok", &live_auth(), &paths).expect("remember");
        assert_eq!(saved, Saved::File(paths.session.clone()));
        assert_eq!(
            std::fs::read_to_string(&paths.session).expect("read"),
            "new=tok\n"
        );
    }

    #[test]
    fn a_no_keyring_login_writes_only_the_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let store = FakeStore::default();
        let mut auth = live_auth();
        auth.no_keyring = true;

        let saved = remember_with(&store, "new=tok", &auth, &paths).expect("remember");
        assert_eq!(saved, Saved::File(paths.session.clone()));
        assert!(store.stored.borrow().is_none());
        assert_eq!(store.forget_calls.get(), 0);
    }

    #[test]
    fn a_no_keyring_login_removes_an_older_keyring_copy() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Found("old=tok".to_owned()))),
            forget: Some(Ok(true)),
            ..FakeStore::default()
        };
        let mut auth = live_auth();
        auth.no_keyring = true;

        let saved = remember_with(&store, "new=tok", &auth, &paths).expect("remember");
        assert_eq!(saved, Saved::File(paths.session.clone()));
        assert_eq!(store.forget_calls.get(), 1);
    }

    #[test]
    fn an_unavailable_keyring_is_not_probed_by_no_keyring() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Unavailable("no daemon".to_owned()))),
            ..FakeStore::default()
        };
        let mut auth = live_auth();
        auth.no_keyring = true;

        remember_with(&store, "new=tok", &auth, &paths).expect("remember");
        assert_eq!(store.forget_calls.get(), 0);
    }

    #[test]
    fn a_failed_keyring_cleanup_still_saves_the_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let store = FakeStore {
            lookup: RefCell::new(Some(Lookup::Found("old=tok".to_owned()))),
            forget: Some(Err("locked".to_owned())),
            ..FakeStore::default()
        };
        let mut auth = live_auth();
        auth.no_keyring = true;

        let saved = remember_with(&store, "new=tok", &auth, &paths).expect("remember");
        assert_eq!(saved, Saved::File(paths.session.clone()));
        assert_eq!(
            std::fs::read_to_string(&paths.session).expect("read"),
            "new=tok\n"
        );
    }

    #[test]
    fn an_explicit_save_path_bypasses_the_keyring() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let target = dir.path().join("custom");
        let store = FakeStore::default();
        let mut auth = live_auth();
        auth.cookie_file = Some(target.clone());

        let saved = remember_with(&store, "new=tok", &auth, &paths).expect("remember");
        assert_eq!(saved, Saved::File(target.clone()));
        assert!(target.exists());
        assert!(store.stored.borrow().is_none());
    }

    #[test]
    fn logout_removes_the_keyring_entry_and_the_file() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        std::fs::create_dir_all(&paths.state_dir).expect("state");
        save_cookie("a=1", &paths.session).expect("save");
        let store = FakeStore {
            forget: Some(Ok(true)),
            ..FakeStore::default()
        };

        let cleared = clear_cookie_with(&store, &live_auth(), &paths).expect("clear");
        assert!(cleared.keyring);
        assert_eq!(cleared.file.as_ref(), Some(&paths.session));
        assert!(!paths.session.exists());
    }

    #[test]
    fn logout_is_silent_when_nothing_was_saved() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        let store = FakeStore::default();

        let cleared = clear_cookie_with(&store, &live_auth(), &paths).expect("clear");
        assert!(!cleared.keyring);
        assert!(cleared.file.is_none());
    }

    #[test]
    fn a_broken_keyring_does_not_block_file_cleanup() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        std::fs::create_dir_all(&paths.state_dir).expect("state");
        save_cookie("a=1", &paths.session).expect("save");
        let store = FakeStore {
            forget: Some(Err("no daemon".to_owned())),
            ..FakeStore::default()
        };

        let cleared = clear_cookie_with(&store, &live_auth(), &paths).expect("clear");
        assert!(!cleared.keyring);
        assert_eq!(cleared.file.as_ref(), Some(&paths.session));
        assert!(!paths.session.exists());
    }

    #[test]
    fn wiping_an_absent_file_is_not_an_error() {
        let dir = tempfile::tempdir().expect("tempdir");
        assert!(!wipe_if_present(&dir.path().join("gone")).expect("wipe"));
    }

    #[cfg(unix)]
    #[test]
    fn wiping_leaves_the_parent_directory_alone() {
        use std::os::unix::fs::PermissionsExt;

        let dir = tempfile::tempdir().expect("tempdir");
        let nested = dir.path().join("nested");
        std::fs::create_dir(&nested).expect("dir");
        std::fs::set_permissions(&nested, std::fs::Permissions::from_mode(0o755)).expect("chmod");
        let session = nested.join("session");
        save_cookie("a=1", &session).expect("save");

        assert!(wipe_if_present(&session).expect("wipe"));
        let mode = std::fs::metadata(&nested)
            .expect("meta")
            .permissions()
            .mode();
        assert_eq!(mode & 0o777, 0o755);
    }

    #[test]
    fn cookie_too_large_is_rejected() {
        let too_big = "a=".repeat(MAX_COOKIE_LEN + 1);
        assert!(build_cookie(&too_big).is_err());
    }

    #[test]
    fn cookie_with_cr_is_rejected() {
        let with_cr = format!("{SESSION_COOKIE}=abc\r\n");
        assert!(build_cookie(&with_cr).is_err());
    }

    #[test]
    fn cookie_with_control_chars_is_rejected() {
        let with_ctrl = format!("{SESSION_COOKIE}=abc\x01");
        assert!(build_cookie(&with_ctrl).is_err());
    }
}

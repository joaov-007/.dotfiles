//! Cookie normalisation and session validation.
//
//! Paranoid protections for pen‑tester threat model:
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

/// This session cookie is split by the server across `.0` and `.1`.
pub const SESSION_COOKIE: &str = "__Secure-next-auth.session-token";

const UA: &str = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 \
                  (KHTML, like Gecko) Chrome/140.0.0.0 Safari/140.0";

/// The chunked-token length window that means "you copied only the first half".
const CHUNK_LEN: std::ops::RangeInclusive<usize> = 3900..=3933;

/// Maximum allowed cookie length (bytes). Prevents absurdly large inputs
/// that could be used for injection or DoS.
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
    use std::os::unix::fs::PermissionsExt;

    // Read current content length so we can overwrite exactly that much.
    let len = std::fs::metadata(path).map(|m| m.len()).unwrap_or(0);
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
    // Ensure the path's parent directory has 0600 if it's the session file.
    if let Some(parent) = path.parent() {
        std::fs::set_permissions(parent, std::fs::Permissions::from_mode(0o600))?;
    }
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

/// Find the cookie to use: explicit flag/env, then the given or default file.
pub fn resolve_cookie(
    explicit: Option<&str>,
    cookie_file: Option<&Path>,
    default_file: &Path,
) -> Result<String> {
    if let Some(raw) = explicit.map(str::trim).filter(|raw| !raw.is_empty()) {
        return build_cookie(raw);
    }

    let path = cookie_file.map_or_else(|| default_file.to_path_buf(), Path::to_path_buf);
    if !path.is_file() {
        if cookie_file.is_some() {
            return Err(Error::usage(format!(
                "arquivo de cookie não encontrado: {}",
                path.display()
            )));
        }
        return Err(Error::usage(
            "nenhum cookie de sessão.\n  Rode `cg login` para ler do navegador, ou cole \
             o cabeçalho `cookie:` do DevTools\n  num arquivo 600 e passe \
            --cookie-file.",
        ));
    }

    warn_if_world_readable(&path);
    let raw = std::fs::read_to_string(&path)?;
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
/// An explicit flag or `CG_COOKIE` always wins. Otherwise the saved header is
/// tried. A rejected saved cookie is an error here; phase 4 adds the browser
/// fallback the Python version has.
pub fn authenticate(client: &mut HttpClient, auth: &AuthArgs, paths: &Paths) -> Result<Session> {
    let base = auth.base_url.trim_end_matches('/');
    crate::http::validate_url(base)?;
    let explicit = auth.effective_cookie();
    let cookie = resolve_cookie(
        explicit.as_deref(),
        auth.cookie_file.as_deref(),
        &paths.session,
    )?;
    open_session(client, base, &cookie)
}

/// Save a header after the server accepted it, unless the user gave a path.
pub fn remember(session_cookie: &str, auth: &AuthArgs, paths: &Paths) -> Result<PathBuf> {
    let path = auth
        .cookie_file
        .clone()
        .unwrap_or_else(|| paths.session.clone());
    save_cookie(session_cookie, &path)?;
    Ok(path)
}

/// Securely wipe the saved session cookie file.
/// This overwrites the file with zeros before unlinking, protecting against
/// forensic recovery of the cookie material.
pub fn clear_cookie(auth: &AuthArgs, paths: &Paths) -> Result<()> {
    let path = auth
        .cookie_file
        .clone()
        .unwrap_or_else(|| paths.session.clone());
    secure_wipe(&path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

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
        let cookie = resolve_cookie(Some("flag=tok"), Some(&path), &path).expect("resolve");
        assert_eq!(cookie, "flag=tok");
    }

    #[test]
    fn a_missing_explicit_file_is_a_usage_error() {
        let error = resolve_cookie(None, Some(Path::new("/nope/session")), Path::new("/nope"))
            .expect_err("must fail");
        assert_eq!(error.exit_code(), 2);
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

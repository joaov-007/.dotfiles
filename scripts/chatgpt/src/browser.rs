//! Harvest the `ChatGPT` session cookie from a logged-in browser profile.
//!
//! Two families are supported, both read-only:
//!
//! * Chromium (Chrome, Chromium, Brave, Edge, Vivaldi, Flatpak variants):
//!   `Cookies` is SQLite; values are AES-128-CBC with a key stored in libsecret
//!   (`secret-tool`). `v10`/`v11` blobs are decrypted here.
//! * Firefox (and LibreWolf): `cookies.sqlite` stores values in plain text.
//!
//! The browser database is copied aside before reading so its locks never block
//! `cg`. That copy holds session tokens, so it is 0600 inside the state
//! directory and removed even when the read fails.
//!
//! On Windows Chromium encrypts with DPAPI and on macOS with the login
//! keychain; this module returns a clear "unsupported" error there instead of
//! guessing. Pasting the cookie header still works on every platform.

use std::path::{Path, PathBuf};
use std::process::Command;

use sha1::{Digest, Sha1};

use crate::config::Paths;
use crate::error::{Error, Result};
use crate::text::truncate_chars;

/// Login cookie the web app sets. Long sessions split it into `.0`, `.1`, ...
pub const SESSION_COOKIE: &str = "__Secure-next-auth.session-token";

const CHROMIUM_STORES: [&str; 8] = [
    "~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/*/Cookies",
    "~/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser/*/Network/Cookies",
    "~/.config/BraveSoftware/Brave-Browser/*/Cookies",
    "~/.config/BraveSoftware/Brave-Browser/*/Network/Cookies",
    "~/.config/chromium/*/Cookies",
    "~/.config/chromium/*/Network/Cookies",
    "~/.config/google-chrome/*/Cookies",
    "~/.config/google-chrome/*/Network/Cookies",
];

const FIREFOX_STORES: [&str; 3] = [
    "~/.var/app/io.gitlab.librewolf-community/config/librewolf/librewolf/*/cookies.sqlite",
    "~/.mozilla/firefox/*/cookies.sqlite",
    "~/.librewolf/*/cookies.sqlite",
];

/// Fallbacks for profiles that never used the desktop keyring.
const OSCRYPT_PASSWORDS: [&str; 3] = ["peanuts", "Brave Safe Storage", "Chrome Safe Storage"];

/// libsecret schema used by Chromium for the "Safe Storage" password.
const OSCRYPT_SCHEMA: &str = "chrome_libsecret_os_crypt_password_v2";

/// Candidate `application` attributes, in preference order.
const OSCRYPT_APPLICATIONS: [&str; 5] =
    ["chrome", "chromium", "brave", "microsoft-edge", "vivaldi"];

/// Chromium 127+ prefixes the plaintext with a 32-byte host digest.
const HOST_DIGEST: usize = 32;

/// One successful harvest.
#[derive(Debug, Clone)]
pub struct Harvest {
    /// `Cookie:` header value.
    pub cookie: String,
    /// Profile database the cookie came from.
    pub store: PathBuf,
    /// Number of `name=value` pairs.
    pub values: usize,
    /// Number of `__Secure-next-auth.session-token` chunks.
    pub chunks: usize,
}

/// Build a `Cookie:` header from the first profile that has a `ChatGPT` session.
///
/// `store` overrides discovery and makes the error message deterministic.
pub fn harvest(paths: &Paths, store: Option<&Path>) -> Result<Harvest> {
    let candidates = if let Some(store) = store {
        vec![expand_home(&store.to_string_lossy())]
    } else {
        discover_stores()
    };
    if candidates.is_empty() {
        return Err(Error::usage(
            "nenhum perfil de navegador encontrado. Passe --store PATH.\n  \
             chromium: <perfil>/Cookies   firefox: <perfil>/cookies.sqlite",
        ));
    }

    for path in candidates.iter().filter(|path| path.is_file()) {
        let cookies = if is_firefox_store(path) {
            read_firefox(paths, path)?
        } else {
            read_chromium(paths, path)?
        };
        let Some(cookie) = session_header(&cookies) else {
            continue;
        };
        let values = cookies.len();
        let chunks = cookies
            .iter()
            .filter(|(name, _)| name.starts_with(&format!("{SESSION_COOKIE}.")))
            .count();
        return Ok(Harvest {
            cookie,
            store: path.clone(),
            values,
            chunks: chunks.max(1),
        });
    }

    Err(Error::usage(
        "nenhum cookie de sessão do ChatGPT nos perfis encontrados — faça login \
         no navegador primeiro, ou passe --cookie-file.",
    ))
}

/// Every profile database that exists, in a stable order.
#[must_use]
pub fn candidate_stores() -> Vec<PathBuf> {
    let mut out = Vec::new();
    for pattern in CHROMIUM_STORES.iter().chain(FIREFOX_STORES.iter()) {
        out.extend(expand_pattern(pattern));
    }
    out.sort();
    out.dedup();
    out.retain(|path| path.is_file());
    out
}

/// Profile databases used by browser processes that are running right now.
///
/// A browser started with `--user-data-dir`, `--profile-directory`, or
/// `--profile` may not live under the default paths. Reading `/proc` finds the
/// live process and its exact profile, which is what a user means by "the
/// browser I am logged in to".
#[must_use]
pub fn running_stores() -> Vec<PathBuf> {
    running_stores_in(Path::new("/proc"))
}

/// Running stores first, then the conventional profile locations.
fn discover_stores() -> Vec<PathBuf> {
    let mut out = running_stores();
    for path in candidate_stores() {
        if !out.contains(&path) {
            out.push(path);
        }
    }
    out
}

fn running_stores_in(proc_root: &Path) -> Vec<PathBuf> {
    let Ok(entries) = std::fs::read_dir(proc_root) else {
        return Vec::new();
    };
    let mut out = Vec::new();
    for entry in entries.flatten() {
        let pid = entry.file_name();
        if !pid.to_string_lossy().chars().all(|ch| ch.is_ascii_digit()) {
            continue;
        }
        let process_dir = entry.path();
        let Ok(raw) = std::fs::read(process_dir.join("cmdline")) else {
            continue;
        };
        let argv = raw
            .split(|byte| *byte == 0)
            .filter(|part| !part.is_empty())
            .map(|part| String::from_utf8_lossy(part).into_owned())
            .collect::<Vec<_>>();
        out.extend(stores_for_argv(&argv, &process_dir.join("cwd")));
    }
    out.sort();
    out.dedup();
    out.retain(|path| path.is_file());
    out
}

fn stores_for_argv(argv: &[String], cwd: &Path) -> Vec<PathBuf> {
    let Some(program) = argv.first() else {
        return Vec::new();
    };
    let name = Path::new(program)
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or_default();
    if is_firefox_process(name) {
        firefox_stores(argv, cwd)
    } else if is_chromium_process(name) {
        chromium_stores(argv, cwd)
    } else {
        Vec::new()
    }
}

fn is_firefox_process(name: &str) -> bool {
    matches!(name, "firefox" | "firefox-bin" | "librewolf" | "waterfox")
}

fn is_chromium_process(name: &str) -> bool {
    matches!(
        name,
        "chrome"
            | "google-chrome"
            | "google-chrome-stable"
            | "chromium"
            | "chromium-browser"
            | "brave"
            | "brave-browser"
            | "microsoft-edge"
            | "msedge"
            | "vivaldi"
            | "vivaldi-bin"
    )
}

fn chromium_stores(argv: &[String], cwd: &Path) -> Vec<PathBuf> {
    let Some(root) = arg_value(argv, "--user-data-dir").map(|path| resolve_path(&path, cwd)) else {
        return Vec::new();
    };
    let profile = arg_value(argv, "--profile-directory").unwrap_or_else(|| "Default".to_owned());
    // The profile is a directory name, never a path.
    if profile.is_empty() || profile == ".." || profile.contains('/') || profile.contains('\\') {
        return Vec::new();
    }
    let base = root.join(profile);
    vec![base.join("Network").join("Cookies"), base.join("Cookies")]
}

fn firefox_stores(argv: &[String], cwd: &Path) -> Vec<PathBuf> {
    let Some(profile) = arg_value(argv, "-profile")
        .or_else(|| arg_value(argv, "--profile"))
        .map(|path| resolve_path(&path, cwd))
    else {
        return Vec::new();
    };
    vec![profile.join("cookies.sqlite")]
}

/// Value of `flag=value` or `flag value`, whichever the browser used.
fn arg_value(argv: &[String], flag: &str) -> Option<String> {
    let mut iter = argv.iter();
    while let Some(arg) = iter.next() {
        if arg == flag {
            return iter.next().cloned();
        }
        if let Some(value) = arg
            .strip_prefix(flag)
            .and_then(|rest| rest.strip_prefix('='))
        {
            return Some(value.to_owned());
        }
    }
    None
}

fn resolve_path(raw: &str, cwd: &Path) -> PathBuf {
    let path = expand_home(raw);
    if path.is_absolute() {
        path
    } else {
        cwd.join(path)
    }
}

fn is_firefox_store(path: &Path) -> bool {
    path.file_name()
        .and_then(|name| name.to_str())
        .is_some_and(|name| name == "cookies.sqlite")
}

fn read_firefox(paths: &Paths, store: &Path) -> Result<Vec<(String, String)>> {
    let snapshot = Snapshot::new(paths, store)?;
    let conn = rusqlite::Connection::open(snapshot.path())?;
    let mut statement = conn.prepare(
        "SELECT name, value FROM moz_cookies \
         WHERE host LIKE '%chatgpt.com' OR host LIKE '%openai.com'",
    )?;
    let rows = statement.query_map([], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
    })?;
    let mut cookies = Vec::new();
    for row in rows {
        let (name, value) = row?;
        if !value.is_empty() {
            cookies.push((name, value));
        }
    }
    Ok(cookies)
}

fn read_chromium(paths: &Paths, store: &Path) -> Result<Vec<(String, String)>> {
    let passwords = chromium_passwords(store);
    let snapshot = Snapshot::new(paths, store)?;
    let conn = rusqlite::Connection::open(snapshot.path())?;
    let mut statement = conn.prepare(
        "SELECT name, encrypted_value, value FROM cookies \
         WHERE host_key LIKE '%chatgpt.com' OR host_key LIKE '%openai.com'",
    )?;
    let rows = statement.query_map([], |row| {
        Ok((
            row.get::<_, String>(0)?,
            row.get::<_, Option<Vec<u8>>>(1)?,
            row.get::<_, Option<String>>(2)?,
        ))
    })?;
    let mut cookies = Vec::new();
    for row in rows {
        let (name, encrypted, plain) = row?;
        if let Some(value) = plain.filter(|value| !value.is_empty()) {
            cookies.push((name, value));
            continue;
        }
        if let Some(blob) = encrypted
            && let Some(value) = decrypt_chromium(&blob, &passwords)
        {
            cookies.push((name, value));
        }
    }
    Ok(cookies)
}

/// A private copy of a live browser database, removed on drop.
///
/// Chromium keeps recent writes in `-wal` while the browser is running, so the
/// sidecars travel with the main file; copying only the database would read a
/// stale snapshot and miss the login cookie.
struct Snapshot {
    path: PathBuf,
}

impl Snapshot {
    fn new(paths: &Paths, store: &Path) -> Result<Self> {
        paths.ensure_state()?;
        let path = paths
            .state_dir
            .join(format!(".cookies-{}.sqlite", std::process::id()));
        for suffix in ["-wal", "-shm", "-journal"] {
            let _ = std::fs::remove_file(sidecar(&path, suffix));
        }
        // Build the guard before copying, so a failed sidecar still cleans up
        // the main file instead of leaving a session token behind.
        let snapshot = Self { path };
        std::fs::copy(store, snapshot.path()).map_err(|error| {
            Error::usage(format!("não foi possível ler {}: {error}", store.display()))
        })?;
        set_private(snapshot.path())?;
        for suffix in ["-wal", "-shm"] {
            let source = sidecar(store, suffix);
            if source.is_file() {
                let target = sidecar(snapshot.path(), suffix);
                std::fs::copy(&source, &target)?;
                set_private(&target)?;
            }
        }
        Ok(snapshot)
    }

    fn path(&self) -> &Path {
        &self.path
    }
}

impl Drop for Snapshot {
    fn drop(&mut self) {
        for suffix in ["", "-wal", "-shm", "-journal"] {
            let _ = std::fs::remove_file(sidecar(&self.path, suffix));
        }
    }
}

fn sidecar(path: &Path, suffix: &str) -> PathBuf {
    let mut name = path.as_os_str().to_owned();
    name.push(suffix);
    PathBuf::from(name)
}

#[cfg(unix)]
fn set_private(path: &Path) -> Result<()> {
    use std::os::unix::fs::PermissionsExt as _;
    std::fs::set_permissions(path, std::fs::Permissions::from_mode(0o600))?;
    Ok(())
}

#[cfg(not(unix))]
fn set_private(_path: &Path) -> Result<()> {
    Ok(())
}

/// Join every cookie, but only when a `ChatGPT` session cookie is present.
fn session_header(cookies: &[(String, String)]) -> Option<String> {
    let has_session = cookies
        .iter()
        .any(|(name, _)| name == SESSION_COOKIE || name.starts_with(&format!("{SESSION_COOKIE}.")));
    if !has_session {
        return None;
    }
    Some(
        cookies
            .iter()
            .map(|(name, value)| format!("{name}={value}"))
            .collect::<Vec<_>>()
            .join("; "),
    )
}

/// Passwords to try for `v10`/`v11`, most likely first.
///
/// `CG_OSCRYPT_PASSWORD` wins, then libsecret (queried once per application),
/// then the legacy constants that old profiles still use.
#[must_use]
pub fn chromium_passwords(store: &Path) -> Vec<String> {
    let mut passwords = Vec::new();
    if let Ok(explicit) = std::env::var("CG_OSCRYPT_PASSWORD") {
        let explicit = explicit.trim().to_owned();
        if !explicit.is_empty() {
            passwords.push(explicit);
        }
    }

    let likely = chromium_application(store);
    let mut applications = Vec::new();
    if let Some(likely) = likely {
        applications.push(likely);
    }
    for application in OSCRYPT_APPLICATIONS {
        if !applications.contains(&application.to_owned()) {
            applications.push(application.to_owned());
        }
    }
    for application in applications {
        if let Some(password) = keyring_password(&application) {
            passwords.push(password);
            break;
        }
    }

    for password in OSCRYPT_PASSWORDS {
        let password = password.to_owned();
        if !passwords.contains(&password) {
            passwords.push(password);
        }
    }
    passwords
}

fn chromium_application(store: &Path) -> Option<String> {
    let text = store.to_string_lossy().to_lowercase();
    let hints = [
        ("brave", "brave"),
        ("chromium", "chromium"),
        ("google-chrome", "chrome"),
        ("microsoft-edge", "microsoft-edge"),
        ("vivaldi", "vivaldi"),
    ];
    hints
        .iter()
        .find(|(needle, _)| text.contains(needle))
        .map(|(_, application)| (*application).to_owned())
}

/// Ask libsecret for Chromium's "Safe Storage" password via `secret-tool`.
fn keyring_password(application: &str) -> Option<String> {
    let tool = which("secret-tool")?;
    let queries = [
        [
            "lookup",
            "application",
            application,
            "xdg:schema",
            OSCRYPT_SCHEMA,
        ],
        ["lookup", "application", application, "", ""],
    ];
    for attributes in queries {
        let mut args = vec![tool.to_string_lossy().into_owned()];
        args.extend(
            attributes
                .iter()
                .filter(|part| !part.is_empty())
                .map(ToString::to_string),
        );
        let output = run_with_timeout(&args)?;
        let password = output.trim().to_owned();
        if !password.is_empty() {
            return Some(password);
        }
    }
    None
}

/// Run a helper with a hard five-second cap when `timeout(1)` exists.
fn run_with_timeout(args: &[String]) -> Option<String> {
    let mut command = if which("timeout").is_some() {
        let mut command = Command::new("timeout");
        command.arg("5");
        command
    } else {
        Command::new(&args[0])
    };
    if command.get_program() == "timeout" {
        command.args(args);
    } else {
        command.args(&args[1..]);
    }
    let output = command.output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8(output.stdout).ok()
}

fn which(name: &str) -> Option<PathBuf> {
    let path = std::env::var_os("PATH")?;
    std::env::split_paths(&path)
        .map(|dir| dir.join(name))
        .find(|candidate| candidate.is_file())
}

/// Decrypt one `v10`/`v11` Chromium value.
fn decrypt_chromium(blob: &[u8], passwords: &[String]) -> Option<String> {
    let prefix = blob.get(..3)?;
    if prefix != b"v10" && prefix != b"v11" {
        return None;
    }
    let ciphertext = blob.get(3..)?;
    if ciphertext.is_empty() || ciphertext.len() % 16 != 0 {
        return None;
    }
    for password in passwords {
        let key = pbkdf2_sha1(password.as_bytes());
        let iv = [b' '; 16];
        let mut buffer = ciphertext.to_vec();
        let Ok(plain) = cbc_decrypt(&key, &iv, &mut buffer) else {
            continue;
        };
        // Some builds prefix the plaintext with a 32-byte host digest.
        for cut in [HOST_DIGEST, 0] {
            let Some(slice) = plain.get(cut..) else {
                continue;
            };
            let Ok(text) = std::str::from_utf8(slice) else {
                continue;
            };
            if !text.is_empty() && text.chars().all(|ch| !ch.is_control()) {
                return Some(text.to_owned());
            }
        }
    }
    None
}

fn cbc_decrypt<'a>(key: &[u8; 16], iv: &[u8; 16], buffer: &'a mut [u8]) -> Result<&'a [u8]> {
    use aes::cipher::{BlockModeDecrypt as _, KeyIvInit as _, block_padding::Pkcs7};

    type Aes128CbcDec = cbc::Decryptor<aes::Aes128>;
    Aes128CbcDec::new(&(*key).into(), &(*iv).into())
        .decrypt_padded::<Pkcs7>(buffer)
        .map_err(|_| Error::usage("não foi possível decifrar o cookie do navegador"))
}

/// PBKDF2-HMAC-SHA1 with one iteration, 16-byte key: the Chromium recipe.
fn pbkdf2_sha1(password: &[u8]) -> [u8; 16] {
    let mut message = b"saltysalt".to_vec();
    message.extend_from_slice(&1_u32.to_be_bytes());
    let digest = hmac_sha1(password, &message);
    let mut key = [0_u8; 16];
    key.copy_from_slice(&digest[..16]);
    key
}

/// HMAC-SHA1 (RFC 2104). SHA-1 is required by the format, not chosen here.
fn hmac_sha1(key: &[u8], message: &[u8]) -> [u8; 20] {
    const BLOCK: usize = 64;
    let mut padded = [0_u8; BLOCK];
    if key.len() > BLOCK {
        let digest = Sha1::digest(key);
        padded[..digest.len()].copy_from_slice(&digest);
    } else {
        padded[..key.len()].copy_from_slice(key);
    }

    let mut inner = Sha1::new();
    let mut outer = Sha1::new();
    for byte in &padded {
        inner.update([byte ^ 0x36]);
        outer.update([byte ^ 0x5c]);
    }
    inner.update(message);
    let inner = inner.finalize();
    outer.update(inner);
    let digest = outer.finalize();
    let mut out = [0_u8; 20];
    out.copy_from_slice(&digest);
    out
}

fn expand_home(pattern: &str) -> PathBuf {
    if let Some(rest) = pattern.strip_prefix("~/")
        && let Some(home) = std::env::var_os("HOME").map(PathBuf::from)
    {
        return home.join(rest);
    }
    PathBuf::from(pattern)
}

/// Expand `*` segments without a glob dependency. Only directory names are
/// expanded, which is all the browser layouts need.
fn expand_pattern(pattern: &str) -> Vec<PathBuf> {
    let expanded = expand_home(pattern);
    let mut paths = vec![PathBuf::from("/")];
    for part in expanded
        .to_string_lossy()
        .split('/')
        .filter(|part| !part.is_empty())
    {
        let mut next = Vec::new();
        for base in &paths {
            if part == "*" {
                let Ok(entries) = std::fs::read_dir(base) else {
                    continue;
                };
                for entry in entries.flatten() {
                    next.push(entry.path());
                }
            } else {
                next.push(base.join(part));
            }
        }
        paths = next;
    }
    paths.retain(|path| path.is_file());
    paths
}

impl Harvest {
    /// One-line summary for `cg login`.
    #[must_use]
    pub fn describe(&self) -> String {
        format!(
            "{} ({} valores, sessão em {} parte(s))",
            truncate_chars(&self.store.to_string_lossy(), 60),
            self.values,
            self.chunks
        )
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hmac_matches_rfc_2104_vector() {
        let digest = hmac_sha1(&[0x0b; 20], b"Hi There");
        assert_eq!(
            digest,
            [
                0xb6, 0x17, 0x31, 0x86, 0x55, 0x05, 0x72, 0x64, 0xe2, 0x8b, 0xc0, 0xb6, 0xfb, 0x37,
                0x8c, 0x8e, 0xf1, 0x46, 0xbe, 0x00,
            ]
        );
    }

    #[test]
    fn pbkdf2_matches_chromium_vectors() {
        assert_eq!(
            pbkdf2_sha1(b"peanuts"),
            [
                0xfd, 0x62, 0x1f, 0xe5, 0xa2, 0xb4, 0x02, 0x53, 0x9d, 0xfa, 0x14, 0x7c, 0xa9, 0x27,
                0x27, 0x78,
            ]
        );
        assert_eq!(
            pbkdf2_sha1(b"Chrome Safe Storage"),
            [
                0xd2, 0xa3, 0x94, 0x9a, 0x08, 0x55, 0xfd, 0x06, 0xee, 0xa5, 0xdb, 0xef, 0xf1, 0xc5,
                0xf2, 0x95,
            ]
        );
    }

    #[test]
    fn header_requires_a_session_cookie() {
        let unrelated = [("theme".to_owned(), "dark".to_owned())];
        assert!(session_header(&unrelated).is_none());

        let cookies = [
            ("theme".to_owned(), "dark".to_owned()),
            (format!("{SESSION_COOKIE}.0"), "a".to_owned()),
            (format!("{SESSION_COOKIE}.1"), "b".to_owned()),
        ];
        let header = session_header(&cookies).expect("session");
        assert!(header.starts_with("theme=dark; __Secure-next-auth.session-token.0=a"));
    }

    #[test]
    fn invalid_blobs_are_rejected_without_panicking() {
        assert!(decrypt_chromium(b"", &["x".to_owned()]).is_none());
        assert!(decrypt_chromium(b"v10", &["x".to_owned()]).is_none());
        assert!(decrypt_chromium(b"v10short", &["x".to_owned()]).is_none());
        assert!(decrypt_chromium(b"v12xxxx", &["x".to_owned()]).is_none());
    }

    #[test]
    fn starred_patterns_expand_directories() {
        let dir = tempfile::tempdir().expect("tempdir");
        let profile = dir.path().join("Default");
        std::fs::create_dir_all(&profile).expect("mkdir");
        std::fs::write(profile.join("Cookies"), b"x").expect("seed");

        let pattern = format!("{}/*/Cookies", dir.path().display());
        assert_eq!(expand_pattern(&pattern), vec![profile.join("Cookies")]);
    }

    #[test]
    fn running_chromium_profile_is_discovered() {
        let dir = tempfile::tempdir().expect("tempdir");
        let proc_root = dir.path().join("proc");
        let pid = proc_root.join("4242");
        std::fs::create_dir_all(&pid).expect("pid dir");

        let user_data = dir.path().join("user-data");
        let cookies = user_data.join("Profile 1").join("Network").join("Cookies");
        std::fs::create_dir_all(cookies.parent().expect("parent")).expect("profile dir");
        std::fs::write(&cookies, b"x").expect("seed");

        let cmdline = format!(
            "/usr/bin/chromium\0--user-data-dir={}\0--profile-directory=Profile 1\0",
            user_data.display()
        );
        std::fs::write(pid.join("cmdline"), cmdline).expect("cmdline");

        assert_eq!(running_stores_in(&proc_root), vec![cookies]);
    }

    #[test]
    fn running_firefox_profile_is_discovered() {
        let dir = tempfile::tempdir().expect("tempdir");
        let proc_root = dir.path().join("proc");
        let pid = proc_root.join("777");
        std::fs::create_dir_all(&pid).expect("pid dir");

        let profile = dir.path().join("ff-profile");
        std::fs::create_dir_all(&profile).expect("profile dir");
        let cookies = profile.join("cookies.sqlite");
        std::fs::write(&cookies, b"x").expect("seed");

        let cmdline = format!(
            "/usr/lib/firefox/firefox\0-profile\0{}\0",
            profile.display()
        );
        std::fs::write(pid.join("cmdline"), cmdline).expect("cmdline");

        assert_eq!(running_stores_in(&proc_root), vec![cookies]);
    }

    #[test]
    fn snapshots_never_linger_in_the_state_dir() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = dir.path().join("cookies.sqlite");
        std::fs::write(&store, b"x").expect("seed");
        let paths = Paths::rooted(dir.path());

        drop(Snapshot::new(&paths, &store).expect("snapshot"));
        // A failed copy must clean up too, not leave a session token behind.
        assert!(Snapshot::new(&paths, &dir.path().join("missing")).is_err());

        let leftovers = std::fs::read_dir(&paths.state_dir)
            .expect("state dir")
            .flatten()
            .filter(|entry| entry.file_name().to_string_lossy().starts_with(".cookies-"))
            .count();
        assert_eq!(leftovers, 0);
    }

    #[test]
    fn a_live_wal_is_copied_with_the_database() {
        let dir = tempfile::tempdir().expect("tempdir");
        let store = dir.path().join("cookies.sqlite");
        let conn = rusqlite::Connection::open(&store).expect("db");
        conn.execute_batch(
            "PRAGMA journal_mode=WAL;
             CREATE TABLE moz_cookies (name TEXT, value TEXT, host TEXT);
             INSERT INTO moz_cookies VALUES \
                ('__Secure-next-auth.session-token.0', 'secret', 'chatgpt.com');",
        )
        .expect("seed");

        // The connection stays open, so the row lives in the -wal sidecar.
        let paths = Paths::rooted(dir.path());
        let cookies = read_firefox(&paths, &store).expect("read");
        assert_eq!(
            cookies,
            vec![(
                "__Secure-next-auth.session-token.0".to_owned(),
                "secret".to_owned()
            )]
        );
        drop(conn);
    }

    #[test]
    fn chromium_application_follows_the_profile_path() {
        assert_eq!(
            chromium_application(Path::new("/home/u/.config/google-chrome/Default/Cookies")),
            Some("chrome".to_owned())
        );
        assert_eq!(
            chromium_application(Path::new("/home/u/.config/chromium/Default/Cookies")),
            Some("chromium".to_owned())
        );
        assert_eq!(chromium_application(Path::new("/tmp/Cookies")), None);
    }
}

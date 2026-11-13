//! OS credential store for the session cookie.
//!
//! The cookie is a bearer credential, so the native store is the default:
//! Secret Service on Linux/BSD (GNOME Keyring, `KWallet`'s `ksecretd`,
//! `KeePassXC`), Credential Manager on Windows, Keychain on macOS. Headless
//! machines, containers and systems without a running secret service fall back
//! to the 0600 file; callers decide when that is acceptable.

use keyring::{Entry, Error as KeyringError};

/// Service name shown by the native keyring viewer.
pub const SERVICE: &str = "cg";

/// `CG_KEYRING=0` (or `off`/`false`/`file`) forces the file backend.
const DISABLE_ENV: &str = "CG_KEYRING";

const DISABLE_VALUES: [&str; 4] = ["0", "off", "false", "file"];

/// Outcome of a keyring read.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Lookup {
    /// The entry exists and holds this value.
    Found(String),
    /// The store is reachable but has no such entry.
    Missing,
    /// The store could not be reached (no daemon, locked, no D-Bus session).
    Unavailable(String),
}

/// The three operations `cg` needs. Kept as a trait so the cookie-resolution
/// precedence can be tested without touching the real keyring.
pub trait Store {
    fn lookup(&self, account: &str) -> Lookup;
    fn store(&self, account: &str, secret: &str) -> std::result::Result<(), String>;
    fn forget(&self, account: &str) -> std::result::Result<bool, String>;
}

/// The platform credential store selected by the `keyring` crate.
#[derive(Debug, Default, Clone, Copy)]
pub struct OsStore;

impl Store for OsStore {
    fn lookup(&self, account: &str) -> Lookup {
        let entry = match Entry::new(SERVICE, account) {
            Ok(entry) => entry,
            Err(error) => return Lookup::Unavailable(error.to_string()),
        };
        match entry.get_password() {
            Ok(secret) => Lookup::Found(secret),
            Err(KeyringError::NoEntry) => Lookup::Missing,
            Err(error) => Lookup::Unavailable(error.to_string()),
        }
    }

    fn store(&self, account: &str, secret: &str) -> std::result::Result<(), String> {
        let entry = Entry::new(SERVICE, account).map_err(|error| error.to_string())?;
        entry
            .set_password(secret)
            .map_err(|error| error.to_string())
    }

    fn forget(&self, account: &str) -> std::result::Result<bool, String> {
        let entry = Entry::new(SERVICE, account).map_err(|error| error.to_string())?;
        match entry.delete_credential() {
            Ok(()) => Ok(true),
            Err(KeyringError::NoEntry) => Ok(false),
            Err(error) => Err(error.to_string()),
        }
    }
}

/// Whether the keyring should be tried at all.
#[must_use]
pub fn enabled() -> bool {
    enabled_from(std::env::var(DISABLE_ENV).ok().as_deref())
}

fn enabled_from(value: Option<&str>) -> bool {
    match value {
        None => true,
        Some(value) => {
            let value = value.trim();
            !DISABLE_VALUES
                .iter()
                .any(|disabled| value.eq_ignore_ascii_case(disabled))
        }
    }
}

/// Stable account key for a base URL, so test servers and production do not
/// overwrite each other.
#[must_use]
pub fn account_for(base_url: &str) -> String {
    let base = base_url.trim();
    let without_scheme = base
        .split_once("://")
        .map_or(base, |(_, after)| after)
        .trim();
    let host = without_scheme
        .split(['/', '?', '#'])
        .next()
        .unwrap_or(without_scheme)
        .trim()
        .to_ascii_lowercase();
    if host.is_empty() {
        "session@chatgpt.com".to_owned()
    } else {
        format!("session@{host}")
    }
}

/// How the entry appears in `seahorse`, `kwalletmanager`, etc.
#[must_use]
pub fn label(account: &str) -> String {
    format!("{SERVICE}/{account}")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[derive(Default)]
    struct FakeStore {
        lookup: Option<Lookup>,
        store: Option<std::result::Result<(), String>>,
        forget: Option<std::result::Result<bool, String>>,
        seen_account: std::cell::RefCell<Option<String>>,
    }

    impl Store for FakeStore {
        fn lookup(&self, account: &str) -> Lookup {
            self.seen_account.replace(Some(account.to_owned()));
            self.lookup.clone().unwrap_or(Lookup::Missing)
        }

        fn store(&self, account: &str, _secret: &str) -> std::result::Result<(), String> {
            self.seen_account.replace(Some(account.to_owned()));
            self.store.clone().unwrap_or(Ok(()))
        }

        fn forget(&self, account: &str) -> std::result::Result<bool, String> {
            self.seen_account.replace(Some(account.to_owned()));
            self.forget.clone().unwrap_or(Ok(false))
        }
    }

    #[test]
    fn the_default_account_is_the_host() {
        assert_eq!(account_for("https://chatgpt.com"), "session@chatgpt.com");
        assert_eq!(
            account_for("http://127.0.0.1:8080/api"),
            "session@127.0.0.1:8080"
        );
    }

    #[test]
    fn account_accepts_sloppy_input() {
        for base in [
            "chatgpt.com",
            "  https://ChatGPT.com/  ",
            "https://chatgpt.com?x=1",
            "https://chatgpt.com#frag",
        ] {
            assert_eq!(account_for(base), "session@chatgpt.com", "{base}");
        }
        assert_eq!(account_for("  "), "session@chatgpt.com");
    }

    #[test]
    fn the_label_matches_the_native_viewer() {
        assert_eq!(label("session@chatgpt.com"), "cg/session@chatgpt.com");
    }

    #[test]
    fn the_keyring_is_enabled_by_default() {
        assert!(enabled_from(None));
        assert!(enabled_from(Some("1")));
        assert!(enabled_from(Some("yes")));
    }

    #[test]
    fn disable_switch_accepts_the_documented_values() {
        for value in ["0", "off", "false", "file", " OFF ", "File"] {
            assert!(!enabled_from(Some(value)), "{value}");
        }
    }

    #[test]
    fn lookup_reports_found_missing_and_unavailable() {
        let found = FakeStore {
            lookup: Some(Lookup::Found("a=1".to_owned())),
            ..FakeStore::default()
        };
        assert_eq!(
            found.lookup("session@chatgpt.com"),
            Lookup::Found("a=1".to_owned())
        );

        let missing = FakeStore::default();
        assert_eq!(missing.lookup("session@chatgpt.com"), Lookup::Missing);

        let unavailable = FakeStore {
            lookup: Some(Lookup::Unavailable("no daemon".to_owned())),
            ..FakeStore::default()
        };
        assert_eq!(
            unavailable.lookup("session@chatgpt.com"),
            Lookup::Unavailable("no daemon".to_owned())
        );
    }

    #[test]
    fn store_propagates_success_and_failure() {
        let ok = FakeStore::default();
        assert!(ok.store("session@chatgpt.com", "a=1").is_ok());
        assert_eq!(
            ok.seen_account.borrow().as_deref(),
            Some("session@chatgpt.com")
        );

        let broken = FakeStore {
            store: Some(Err("locked".to_owned())),
            ..FakeStore::default()
        };
        assert_eq!(
            broken.store("session@chatgpt.com", "a=1").unwrap_err(),
            "locked"
        );
    }

    #[test]
    fn forget_reports_whether_something_was_removed() {
        let removed = FakeStore {
            forget: Some(Ok(true)),
            ..FakeStore::default()
        };
        assert_eq!(removed.forget("session@chatgpt.com"), Ok(true));

        let absent = FakeStore::default();
        assert_eq!(absent.forget("session@chatgpt.com"), Ok(false));

        let broken = FakeStore {
            forget: Some(Err("no daemon".to_owned())),
            ..FakeStore::default()
        };
        assert_eq!(
            broken.forget("session@chatgpt.com").unwrap_err(),
            "no daemon"
        );
    }

    #[test]
    #[ignore = "needs a running desktop keyring"]
    fn the_os_store_round_trips_a_probe() {
        let account = format!("cg-test-{}", std::process::id());
        let store = OsStore;
        store.store(&account, "probe").expect("store");
        assert_eq!(store.lookup(&account), Lookup::Found("probe".to_owned()));
        assert_eq!(store.forget(&account), Ok(true));
        assert_eq!(store.lookup(&account), Lookup::Missing);
    }
}

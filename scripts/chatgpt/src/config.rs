//! Filesystem locations. Everything is overridable so tests never touch
//! `$HOME`, and so the Python version's state directory can be reused as-is.
//! On Windows the same layout hangs off `%USERPROFILE%` and `%LOCALAPPDATA%`.

use std::path::{Path, PathBuf};

use crate::error::{Error, Result};

/// `HOME` on Unix, `USERPROFILE` on Windows.
fn home_dir() -> Option<PathBuf> {
    pick_home(
        std::env::var_os("HOME").map(PathBuf::from),
        std::env::var_os("USERPROFILE").map(PathBuf::from),
    )
}

fn pick_home(home: Option<PathBuf>, userprofile: Option<PathBuf>) -> Option<PathBuf> {
    home.or(userprofile)
}

/// XDG state dir on Unix, `%LOCALAPPDATA%` on Windows.
fn state_base(
    home: &Path,
    xdg: Option<PathBuf>,
    local_appdata: Option<PathBuf>,
    windows: bool,
) -> PathBuf {
    if let Some(xdg) = xdg {
        return xdg;
    }
    if windows {
        local_appdata.unwrap_or_else(|| home.join("AppData").join("Local"))
    } else {
        home.join(".local").join("state")
    }
}

/// XDG cache dir on Unix, `%LOCALAPPDATA%\cg\cache` on Windows.
fn cache_base(
    home: &Path,
    xdg: Option<PathBuf>,
    local_appdata: Option<PathBuf>,
    windows: bool,
) -> PathBuf {
    if let Some(xdg) = xdg {
        return xdg;
    }
    if windows {
        local_appdata.unwrap_or_else(|| home.join("AppData").join("Local"))
    } else {
        home.join(".cache")
    }
}

/// Platform-compliant paths used by every command.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Paths {
    pub state_dir: PathBuf,
    pub db: PathBuf,
    pub reports: PathBuf,
    pub cache_dir: PathBuf,
    pub conv_cache: PathBuf,
    pub log: PathBuf,
    pub export_dir: PathBuf,
    pub session: PathBuf,
    pub lock: PathBuf,
}

impl Paths {
    /// Read the environment once and derive every path from it.
    pub fn from_env() -> Result<Self> {
        let home = home_dir().ok_or_else(|| {
            Error::usage("HOME (ou USERPROFILE no Windows) não definido; passe CG_STATE_DIR")
        })?;
        let windows = cfg!(windows);

        let state = std::env::var_os("CG_STATE_DIR").map_or_else(
            || {
                state_base(
                    &home,
                    std::env::var_os("XDG_STATE_HOME").map(PathBuf::from),
                    std::env::var_os("LOCALAPPDATA").map(PathBuf::from),
                    windows,
                )
                .join("cg")
            },
            PathBuf::from,
        );
        let cache = cache_base(
            &home,
            std::env::var_os("XDG_CACHE_HOME").map(PathBuf::from),
            std::env::var_os("LOCALAPPDATA").map(PathBuf::from),
            windows,
        )
        .join("cg");
        let export = std::env::var_os("CG_EXPORT_DIR")
            .map_or_else(|| home.join("Documents").join("ChatGPT"), PathBuf::from);

        Ok(Self::from_parts(Some(state), Some(cache), Some(export)))
    }

    /// Pure constructor, used by tests and by `from_env`.
    pub fn from_parts(
        state: Option<PathBuf>,
        cache: Option<PathBuf>,
        export: Option<PathBuf>,
    ) -> Self {
        let state_dir = state.unwrap_or_else(|| PathBuf::from(".").join("cg-state"));
        let cache_dir = cache.unwrap_or_else(|| PathBuf::from(".").join("cg-cache"));
        let export_dir = export.unwrap_or_else(|| PathBuf::from(".").join("cg-export"));

        Self {
            db: state_dir.join("cg.db"),
            reports: state_dir.join("reports"),
            session: state_dir.join("session"),
            lock: state_dir.join("run.lock"),
            conv_cache: cache_dir.join("convs"),
            log: cache_dir.join("cg.log"),
            state_dir,
            cache_dir,
            export_dir,
        }
    }

    /// Build a self-contained layout under a temporary root.
    #[must_use]
    pub fn rooted(root: &Path) -> Self {
        Self::from_parts(
            Some(root.join("state")),
            Some(root.join("cache")),
            Some(root.join("export")),
        )
    }

    /// Create the directories a command is about to write to.
    pub fn ensure_state(&self) -> Result<()> {
        std::fs::create_dir_all(&self.state_dir)?;
        std::fs::create_dir_all(&self.reports)?;
        Ok(())
    }

    /// Cache is disposable: create it lazily.
    pub fn ensure_cache(&self) -> Result<()> {
        std::fs::create_dir_all(&self.cache_dir)?;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn explicit_overrides_win() {
        let paths = Paths::from_parts(
            Some(PathBuf::from("/tmp/s")),
            Some(PathBuf::from("/tmp/c")),
            Some(PathBuf::from("/tmp/e")),
        );
        assert_eq!(paths.db, PathBuf::from("/tmp/s/cg.db"));
        assert_eq!(paths.reports, PathBuf::from("/tmp/s/reports"));
        assert_eq!(paths.session, PathBuf::from("/tmp/s/session"));
        assert_eq!(paths.conv_cache, PathBuf::from("/tmp/c/convs"));
        assert_eq!(paths.export_dir, PathBuf::from("/tmp/e"));
    }

    #[test]
    fn rooted_layout_is_self_contained() {
        let root = PathBuf::from("/tmp/example");
        let paths = Paths::rooted(&root);
        assert!(paths.db.starts_with(&root));
        assert!(paths.cache_dir.starts_with(&root));
        assert!(paths.export_dir.starts_with(&root));
    }

    #[test]
    fn home_prefers_home_and_falls_back_to_userprofile() {
        let home = PathBuf::from("/home/ana");
        let profile = PathBuf::from("C:/Users/ana");
        assert_eq!(
            pick_home(Some(home.clone()), Some(profile.clone())),
            Some(home)
        );
        assert_eq!(pick_home(None, Some(profile.clone())), Some(profile));
        assert_eq!(pick_home(None, None), None);
    }

    #[test]
    fn the_state_dir_follows_xdg_on_unix() {
        let base = state_base(Path::new("/home/ana"), None, None, false);
        assert_eq!(base, PathBuf::from("/home/ana/.local/state"));
    }

    #[test]
    fn an_explicit_xdg_state_dir_wins_on_every_platform() {
        let xdg = PathBuf::from("/srv/state");
        let base = state_base(
            Path::new("/home/ana"),
            Some(xdg.clone()),
            Some(PathBuf::from("C:/Users/ana/AppData/Local")),
            true,
        );
        assert_eq!(base, xdg);
    }

    #[test]
    fn windows_uses_local_app_data() {
        let base = state_base(
            Path::new("C:/Users/ana"),
            None,
            Some(PathBuf::from("C:/Users/ana/AppData/Local")),
            true,
        );
        assert_eq!(base, PathBuf::from("C:/Users/ana/AppData/Local"));
    }

    #[test]
    fn windows_without_local_app_data_still_has_a_home() {
        let base = state_base(Path::new("C:/Users/ana"), None, None, true);
        assert_eq!(base, PathBuf::from("C:/Users/ana/AppData/Local"));
    }

    #[test]
    fn the_cache_dir_follows_xdg_on_unix() {
        let base = cache_base(Path::new("/home/ana"), None, None, false);
        assert_eq!(base, PathBuf::from("/home/ana/.cache"));
    }

    #[test]
    fn an_explicit_xdg_cache_dir_wins() {
        let xdg = PathBuf::from("/srv/cache");
        let base = cache_base(
            Path::new("/home/ana"),
            Some(xdg.clone()),
            Some(PathBuf::from("C:/Users/ana/AppData/Local")),
            true,
        );
        assert_eq!(base, xdg);
    }

    #[test]
    fn windows_cache_falls_back_to_local_app_data() {
        let base = cache_base(
            Path::new("C:/Users/ana"),
            None,
            Some(PathBuf::from("C:/Users/ana/AppData/Local")),
            true,
        );
        assert_eq!(base, PathBuf::from("C:/Users/ana/AppData/Local"));
    }
}

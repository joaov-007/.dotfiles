//! Filesystem locations. Everything is overridable so tests never touch
//! `$HOME`, and so the Python version's state directory can be reused as-is.

use std::path::{Path, PathBuf};

use crate::error::{Error, Result};

/// XDG-compliant paths used by every command.
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
        let home = std::env::var_os("HOME")
            .map(PathBuf::from)
            .ok_or_else(|| Error::usage("HOME não definido; passe CG_STATE_DIR"))?;

        let state = std::env::var_os("CG_STATE_DIR")
            .map(PathBuf::from)
            .or_else(|| {
                std::env::var_os("XDG_STATE_HOME")
                    .map(PathBuf::from)
                    .or_else(|| Some(home.join(".local/state")))
                    .map(|base| base.join("cg"))
            });
        let cache = std::env::var_os("XDG_CACHE_HOME")
            .map(PathBuf::from)
            .or_else(|| Some(home.join(".cache")))
            .map(|base| base.join("cg"));
        let export = std::env::var_os("CG_EXPORT_DIR")
            .map(PathBuf::from)
            .or_else(|| Some(home.join("Documents/ChatGPT")));

        Ok(Self::from_parts(state, cache, export))
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
}

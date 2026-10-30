//! One error type for the whole crate, plus the exit codes the CLI promises.
//!
//! Exit codes are part of the interface (scripts and systemd read them):
//!   0  success
//!   1  ordinary failure (bad input, I/O, network, partial batch)
//!   2  authentication/authorisation failure, or invalid usage
//!   3  rate limited (safe to retry later)
//!   130 interrupted by the user

use std::path::PathBuf;

/// Result alias used across the crate.
pub type Result<T> = std::result::Result<T, Error>;

/// Everything that can stop a command.
#[derive(Debug, thiserror::Error)]
pub enum Error {
    #[error("{0}")]
    Usage(String),

    #[error("índice vazio — rode `cg ingest <export>` ou `cg sync` primeiro")]
    EmptyIndex,

    #[error("sessão recusada: {0}")]
    SessionExpired(String),

    #[error("HTTP 429 — {0}")]
    RateLimited(String),

    #[error("HTTP {status} em {url}: {body}")]
    Http {
        status: u16,
        url: String,
        body: String,
    },

    #[error("não foi possível acessar {url}: {reason}")]
    Network { url: String, reason: String },

    #[error("outra execução do cg ainda está escrevendo ({0})")]
    LockBusy(PathBuf),

    #[error("{0}")]
    Invalid(String),

    #[error(transparent)]
    Io(#[from] std::io::Error),

    #[error(transparent)]
    Json(#[from] serde_json::Error),

    #[error(transparent)]
    Db(#[from] rusqlite::Error),

    #[error(transparent)]
    Zip(#[from] zip::result::ZipError),
}

impl Error {
    /// Build a usage error without repeating `Error::Usage(..)` everywhere.
    pub fn usage(message: impl Into<String>) -> Self {
        Self::Usage(message.into())
    }

    /// Build a lock-state error (poisoned mutex, corrupted lease).
    #[must_use]
    pub fn invalid_lock(message: impl Into<String>) -> Self {
        Self::Invalid(message.into())
    }

    /// The process exit code that matches this error.
    #[must_use]
    pub fn exit_code(&self) -> i32 {
        match self {
            Self::SessionExpired(_)
            | Self::Usage(_)
            | Self::Http {
                status: 401 | 403, ..
            } => 2,
            Self::RateLimited(_) => 3,
            _ => 1,
        }
    }
}

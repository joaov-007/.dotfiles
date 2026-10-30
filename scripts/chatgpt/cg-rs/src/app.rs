//! Dispatch from parsed arguments to commands.

use crate::cli::{Cli, Command};
use crate::commands;
use crate::config::Paths;
use crate::daemon;
use crate::error::Result;

/// Run the selected command and return the process exit code.
pub fn run(cli: Cli) -> Result<i32> {
    let paths = Paths::from_env()?;
    if cli.debug {
        eprintln!(
            "debug: banco={} cache={} export={}",
            paths.db.display(),
            paths.cache_dir.display(),
            paths.export_dir.display()
        );
    }

    match cli.command {
        Command::Ingest { source } => commands::ingest::run(&paths, &source).map(|()| 0),
        Command::Plan { days } => commands::plan::run(&paths, days).map(|()| 0),
        Command::Status => commands::status::run(&paths).map(|()| 0),
        Command::Login(args) => commands::login::run(&paths, &args).map(|()| 0),
        Command::Auth(args) => commands::auth::run(&paths, &args).map(|()| 0),
        Command::Sync(args) => commands::sync::run(&paths, &args),
        Command::Projects(args) => commands::projects::run(&paths, &args).map(|()| 0),
        Command::Organize(args) => commands::organize::run(&paths, &args),
        Command::Unorganize(args) => commands::unorganize::run(&paths, &args),
        Command::Move(args) => commands::move_batch::run(&paths, &args),
        Command::Archive(args) => commands::archive::run(&paths, &args),
        Command::Unarchive(args) => commands::unarchive::run(&paths, &args),
        Command::Daemon(args) => daemon::run_daemon(&args).map(|code| code as i32),
    }
}

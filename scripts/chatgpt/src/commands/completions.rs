//! `cg completions`: emit a completion script for the current CLI.

use std::io::Write as _;

use clap::CommandFactory as _;

use crate::cli::{Cli, CompletionsArgs};
use crate::error::Result;

pub fn run(args: &CompletionsArgs) -> Result<i32> {
    let mut command = Cli::command();
    let mut buffer = Vec::new();
    clap_complete::generate(args.shell, &mut command, "cg", &mut buffer);
    match std::io::stdout().write_all(&buffer) {
        Ok(()) => Ok(0),
        // `cg completions bash | head` is a normal thing to do.
        Err(error) if error.kind() == std::io::ErrorKind::BrokenPipe => Ok(0),
        Err(error) => Err(error.into()),
    }
}

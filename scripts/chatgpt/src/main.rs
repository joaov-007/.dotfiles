//! Thin binary: parse arguments, run, map errors to the documented exit codes.

use std::process::ExitCode;

use clap::Parser;

fn main() -> ExitCode {
    let cli = cg::cli::Cli::parse();
    match cg::app::run(cli) {
        Ok(code) => ExitCode::from(u8::try_from(code).unwrap_or(1)),
        Err(error) => {
            eprintln!("erro: {error}");
            ExitCode::from(u8::try_from(error.exit_code()).unwrap_or(1))
        }
    }
}

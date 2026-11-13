//! `cg log`: tail the local debug log written by `--debug`.

use crate::cli::LogArgs;
use crate::config::Paths;
use crate::error::Result;

pub fn run(paths: &Paths, args: &LogArgs) -> Result<i32> {
    if args.path {
        println!("{}", paths.log.display());
        return Ok(0);
    }

    println!("arquivo: {}", paths.log.display());
    let text = match std::fs::read_to_string(&paths.log) {
        Ok(text) => text,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
            println!("(vazio — rode qualquer comando com --debug para começar)");
            return Ok(1);
        }
        Err(error) => return Err(error.into()),
    };

    let lines = text.lines().collect::<Vec<_>>();
    let start = lines.len().saturating_sub(args.lines);
    for line in &lines[start..] {
        println!("{line}");
    }
    Ok(0)
}

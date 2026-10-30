//! `cg status`: what is indexed and where the files live.

use std::path::Path;

use crate::config::Paths;
use crate::error::Result;
use crate::store::Index;

/// Print a short, offline-only summary.
pub fn run(paths: &Paths) -> Result<()> {
    let index = Index::open(&paths.db)?;
    let total = index.count()?;
    println!("índice : {total} conversas");

    let gone = index.count_gone()?;
    if gone > 0 {
        println!("sumidas: {gone} (404 no site — fora dos relatórios)");
    }
    if let Some(source) = index.latest_source()? {
        println!(
            "último export: {} · {} conversas · {}",
            file_name(&source.path),
            source.conversations,
            source.seen_at
        );
    }
    println!("banco  : {}", paths.db.display());
    println!("log    : {}", paths.log.display());
    Ok(())
}

fn file_name(path: &str) -> String {
    Path::new(path)
        .file_name()
        .and_then(|name| name.to_str())
        .map_or_else(|| path.to_owned(), str::to_owned)
}

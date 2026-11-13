//! `cg ingest`: read an official export into the local index.

use std::path::Path;

use chrono::Local;
use sha2::{Digest, Sha256};

use crate::config::Paths;
use crate::error::{Error, Result};
use crate::export::load_export;
use crate::store::Index;

/// Index every conversation in `source`. Re-running is safe: rows are updated,
/// never duplicated.
pub fn run(paths: &Paths, source: &Path) -> Result<()> {
    if !source.exists() {
        return Err(Error::usage(format!("{} não encontrado", source.display())));
    }

    let batch = load_export(source)?;
    paths.ensure_state()?;
    let index = Index::open(&paths.db)?;
    let now = Local::now().format("%Y-%m-%dT%H:%M:%S").to_string();

    let mut new = 0_usize;
    let mut updated = 0_usize;
    for conversation in &batch.conversations {
        if index.record(conversation, &source_name(source), &now, None)? {
            new += 1;
        } else {
            updated += 1;
        }
    }

    let (digest, size) = if source.is_file() {
        (sha256_file(source)?, std::fs::metadata(source)?.len())
    } else {
        (String::new(), 0)
    };
    index.record_source(
        &source.to_string_lossy(),
        &digest,
        size,
        &now,
        batch.conversations.len(),
    )?;

    println!(
        "export    : {} → {}",
        source_name(source),
        batch.members.join(", ")
    );
    println!("lidas     : {}", batch.conversations.len());
    println!("novas     : {new}");
    println!("atualizadas: {updated}");
    println!("índice    : {} conversas", index.count()?);
    println!("\npróximo passo: cg plan");
    Ok(())
}

fn source_name(source: &Path) -> String {
    source
        .file_name()
        .and_then(|name| name.to_str())
        .map_or_else(|| source.display().to_string(), str::to_owned)
}

fn sha256_file(path: &Path) -> Result<String> {
    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    std::io::copy(&mut file, &mut hasher)?;
    Ok(format!("{:x}", hasher.finalize()))
}

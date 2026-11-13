//! `cg projects`: list the account's Projects and local conversation counts.

use crate::api::list_projects;
use crate::auth::authenticate;
use crate::cli::AuthArgs;
use crate::config::Paths;
use crate::error::Result;
use crate::live;
use crate::store::Index;
use crate::text::truncate_chars;

/// Read-only: one API call plus the local index.
pub fn run(paths: &Paths, args: &AuthArgs) -> Result<()> {
    let base = args.base_url.trim_end_matches('/').to_owned();
    let mut client = live::client(1.0, live::RETRIES);
    let session = authenticate(&mut client, args, paths)?;
    let mut projects = list_projects(&mut client, &base, &session.access_token)?;

    let index = Index::open(&paths.db)?;
    let counts = index.project_counts()?;
    let loose = index.loose_count()?;

    projects.sort_by(|left, right| {
        let left_count = counts.get(left.id.as_str()).copied().unwrap_or(0);
        let right_count = counts.get(right.id.as_str()).copied().unwrap_or(0);
        right_count
            .cmp(&left_count)
            .then_with(|| left.name.cmp(&right.name))
    });

    println!("projetos: {}", projects.len());
    for project in &projects {
        let count = counts.get(project.id.as_str()).copied().unwrap_or(0);
        println!(
            "  {:30} {count:>3} conversas  {}",
            truncate_chars(&project.name, 30),
            project.id
        );
    }
    println!("\nfora de Projects: {loose} conversas indexadas");
    Ok(())
}

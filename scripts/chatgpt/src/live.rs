//! Shared plumbing for the live commands.
//!
//! Everything here is small and side-effect free except the client builders, so
//! the commands stay readable and the safety rules live in one place.

use std::collections::HashSet;
use std::path::Path;

use chrono::Local;

use crate::api::Project;
use crate::error::{Error, Result};
use crate::http::{HttpClient, Throttle};
use crate::model::ConversationId;
use crate::projects::project_key;

/// Default retry budget for a command that has no `--max-retries` flag.
pub const RETRIES: u32 = 4;

/// Wall-clock stamp used in journals and index rows.
#[must_use]
pub fn now_string() -> String {
    Local::now().format("%Y-%m-%dT%H:%M:%S").to_string()
}

/// A network client with the command's pace and retry budget.
#[must_use]
pub fn client(sleep: f64, retries: u32) -> HttpClient {
    HttpClient::new(
        Box::new(crate::http::UreqTransport::default()),
        Throttle::new(sleep),
        retries,
    )
}

/// Turn the statuses that must abort the whole run into an error.
#[must_use]
pub fn abort_for(status: u16) -> Option<Error> {
    match status {
        401 | 403 => Some(Error::SessionExpired(format!(
            "HTTP {status} — sessão inválida ou sem permissão"
        ))),
        429 => Some(Error::RateLimited(
            "rate limit — espere e rode o mesmo comando para retomar".to_owned(),
        )),
        _ => None,
    }
}

/// Find a Project by folded name, or explain how to list them.
pub fn project_named<'a>(projects: &'a [Project], name: &str) -> Result<&'a Project> {
    let key = project_key(name);
    projects
        .iter()
        .find(|project| project_key(&project.name) == key)
        .ok_or_else(|| {
            Error::usage(format!(
                "projeto '{name}' não encontrado.\n  Veja com: cg projects\n  \
                 Ou crie com: cg move --to '{name}' --create ..."
            ))
        })
}

/// Read one conversation id per line. Blank lines are ignored; an invalid line
/// is reported instead of silently dropped.
pub fn read_ids(path: &Path) -> Result<Vec<ConversationId>> {
    let text = std::fs::read_to_string(path).map_err(|error| {
        Error::usage(format!("não foi possível ler {}: {error}", path.display()))
    })?;
    let mut ids = Vec::new();
    let mut seen = HashSet::new();
    for (index, line) in text.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let Some(id) = ConversationId::parse(line) else {
            return Err(Error::usage(format!(
                "id inválido na linha {} de {}: {line:?}",
                index + 1,
                path.display()
            )));
        };
        if seen.insert(id.clone()) {
            ids.push(id);
        }
    }
    Ok(ids)
}

/// True when the string means "no project" (the same spellings as Python).
#[must_use]
pub fn is_unassigned(name: &str) -> bool {
    matches!(
        name.trim().to_ascii_lowercase().as_str(),
        "" | "none" | "null" | "unassigned" | "unknown" | "sem projeto" | "no project"
    )
}

/// Parse a journal `from` value into a writable Project id.
pub fn parse_project_id(raw: Option<&str>) -> Result<Option<crate::model::ProjectId>> {
    match raw {
        None => Ok(None),
        Some(raw) => crate::model::ProjectId::parse(raw)
            .map(Some)
            .ok_or_else(|| Error::Invalid(format!("id de Project inválido no log: {raw:?}"))),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::ProjectId;

    fn project(name: &str, id: &str) -> Project {
        Project {
            id: ProjectId::parse(id).expect("id"),
            name: name.to_owned(),
        }
    }

    #[test]
    fn projects_are_found_by_folded_name() {
        let projects = vec![project("Linux & Arch", "g-p-111")];
        let found = project_named(&projects, "linux arch").expect("found");
        assert_eq!(found.id.as_str(), "g-p-111");
        assert!(project_named(&projects, "Go").is_err());
    }

    #[test]
    fn id_lists_skip_blanks_and_duplicates() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("ids.txt");
        std::fs::write(&path, "aaaaaaaa-1\n\n aaaaaaaa-2 \naaaaaaaa-1\n").expect("write");
        let ids = read_ids(&path).expect("ids");
        assert_eq!(ids.len(), 2);
        assert_eq!(ids[0].as_str(), "aaaaaaaa-1");
        assert_eq!(ids[1].as_str(), "aaaaaaaa-2");
    }

    #[test]
    fn an_invalid_id_names_its_line() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("ids.txt");
        std::fs::write(&path, "aaaaaaaa-1\n../etc/passwd\n").expect("write");
        let error = read_ids(&path).expect_err("must fail");
        assert!(error.to_string().contains("linha 2"));
    }

    #[test]
    fn abort_statuses_map_to_the_documented_codes() {
        assert_eq!(abort_for(401).expect("auth").exit_code(), 2);
        assert_eq!(abort_for(403).expect("auth").exit_code(), 2);
        assert_eq!(abort_for(429).expect("limit").exit_code(), 3);
        assert!(abort_for(404).is_none());
    }

    #[test]
    fn unassigned_spellings_are_recognised() {
        for name in ["", "none", "NULL", "sem projeto", "No Project"] {
            assert!(is_unassigned(name), "{name}");
        }
        assert!(!is_unassigned("Inbox"));
    }
}

//! Markdown notes and the safe write path used by `cg export`.
//!
//! Notes are disposable output, but a note the user edited by hand is not: the
//! writer keeps it unless `--overwrite` was given. Writes go through a temp
//! file so an interrupted run never leaves a truncated note behind.

use std::fs;
use std::io::Write as _;
use std::path::{Path, PathBuf};

use crate::error::Result;
use crate::model::Conversation;
use crate::text::{folder_name, slugify};

/// What happened to one note.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Outcome {
    Written,
    Unchanged,
    Kept,
}

impl Outcome {
    #[must_use]
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Written => "written",
            Self::Unchanged => "unchanged",
            Self::Kept => "kept",
        }
    }
}

/// Render one conversation as a self-contained Markdown note.
#[must_use]
pub fn render(conversation: &Conversation, project: Option<&str>) -> String {
    let mut out = String::new();
    let title = if conversation.title.is_empty() {
        "(sem título)"
    } else {
        conversation.title.as_str()
    };
    out.push_str("# ");
    out.push_str(title);
    out.push_str("\n\n");

    let mut meta = Vec::new();
    meta.push(format!("- ChatGPT: {}", conversation.link()));
    if let Some(created) = conversation.created.as_ref() {
        meta.push(format!("- Criado: {}", created.to_rfc3339()));
    }
    if conversation.archived {
        meta.push("- Arquivado: sim".to_owned());
    }
    if let Some(project) = project.filter(|name| !name.is_empty()) {
        meta.push(format!("- Project: {project}"));
    }
    for line in meta {
        out.push_str(&line);
        out.push('\n');
    }
    out.push_str("\n---\n\n");

    if conversation.turns.is_empty() {
        out.push_str("_Sem conteúdo._\n");
        return out;
    }
    for turn in &conversation.turns {
        match turn.role {
            crate::model::Role::User => out.push_str("## Pergunta\n\n"),
            crate::model::Role::Assistant => out.push_str("## Resposta\n\n"),
        }
        out.push_str(turn.text.trim_end());
        out.push_str("\n\n");
    }
    out
}

/// `slug-<first 8 chars of id>.md`, the same shape the Python tool writes.
#[must_use]
pub fn file_name(conversation: &Conversation) -> String {
    format!(
        "{}-{}.md",
        slugify(&conversation.title, 80),
        conversation.id.short(8)
    )
}

/// Folder for one project, relative to the export root.
#[must_use]
pub fn project_dir(project: &str) -> String {
    folder_name(project)
}

/// Write `text` to `path`, respecting hand edits.
///
/// * identical content -> [`Outcome::Unchanged`];
/// * different content without `overwrite` -> [`Outcome::Kept`];
/// * otherwise the file is replaced atomically -> [`Outcome::Written`].
pub fn write_note(path: &Path, text: &str, overwrite: bool) -> Result<Outcome> {
    if let Ok(current) = fs::read_to_string(path) {
        if current == text {
            return Ok(Outcome::Unchanged);
        }
        if !overwrite {
            return Ok(Outcome::Kept);
        }
    }
    atomic_write(path, text.as_bytes())?;
    Ok(Outcome::Written)
}

/// Temp file + rename in the same directory. Shared with the conversation
/// cache and the generated systemd units.
pub fn atomic_write(path: &Path, bytes: &[u8]) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = temp_path(path);
    let result = (|| -> Result<()> {
        let mut file = fs::File::create(&tmp)?;
        file.write_all(bytes)?;
        file.sync_all()?;
        drop(file);
        fs::rename(&tmp, path)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&tmp);
    }
    result
}

fn temp_path(path: &Path) -> PathBuf {
    let name = path
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or("note");
    path.with_file_name(format!(".{name}.{}.tmp", std::process::id()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::model::{ConversationId, Role, Turn};

    fn conversation() -> Conversation {
        Conversation {
            id: ConversationId::parse("aaaaaaaa-1111").expect("id"),
            title: "Pacman e systemd".to_owned(),
            created: None,
            archived: false,
            project_id: None,
            turns: vec![
                Turn {
                    role: Role::User,
                    text: "como limpo o cache?".to_owned(),
                },
                Turn {
                    role: Role::Assistant,
                    text: "pacman -Sc".to_owned(),
                },
            ],
        }
    }

    #[test]
    fn renders_metadata_and_turns() {
        let text = render(&conversation(), Some("Linux"));
        assert!(text.starts_with("# Pacman e systemd"));
        assert!(text.contains("- ChatGPT: https://chatgpt.com/c/aaaaaaaa-1111"));
        assert!(text.contains("- Project: Linux"));
        assert!(text.contains("## Pergunta\n\ncomo limpo o cache?"));
        assert!(text.contains("## Resposta\n\npacman -Sc"));
    }

    #[test]
    fn empty_body_stays_explicit() {
        let mut conv = conversation();
        conv.turns.clear();
        assert!(render(&conv, None).contains("_Sem conteúdo._"));
    }

    #[test]
    fn file_name_uses_slug_and_short_id() {
        assert_eq!(file_name(&conversation()), "pacman-e-systemd-aaaaaaaa.md");
    }

    #[test]
    fn hand_edits_are_kept_without_overwrite() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("note.md");
        fs::write(&path, "edited by hand\n").expect("seed");

        assert_eq!(
            write_note(&path, "generated\n", false).expect("write"),
            Outcome::Kept
        );
        assert_eq!(fs::read_to_string(&path).expect("read"), "edited by hand\n");

        assert_eq!(
            write_note(&path, "generated\n", true).expect("write"),
            Outcome::Written
        );
        assert_eq!(fs::read_to_string(&path).expect("read"), "generated\n");
    }

    #[test]
    fn identical_content_is_unchanged() {
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("note.md");
        fs::write(&path, "same\n").expect("seed");
        assert_eq!(
            write_note(&path, "same\n", false).expect("write"),
            Outcome::Unchanged
        );
    }
}

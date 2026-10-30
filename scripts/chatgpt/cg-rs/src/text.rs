//! Small text helpers shared by the parser and the report writers.

use unicode_normalization::UnicodeNormalization;
use unicode_normalization::char::is_combining_mark;

/// Collapse every run of whitespace into one space and trim the ends.
#[must_use]
pub fn collapse_ws(text: &str) -> String {
    text.split_whitespace().collect::<Vec<_>>().join(" ")
}

/// Keep at most `limit` characters (not bytes).
#[must_use]
pub fn truncate_chars(text: &str, limit: usize) -> String {
    if text.chars().count() <= limit {
        return text.to_owned();
    }
    text.chars().take(limit).collect()
}

/// Fold accents and case: `Música` -> `musica`.
#[must_use]
pub fn fold(text: &str) -> String {
    text.to_lowercase()
        .nfd()
        .filter(|c| !is_combining_mark(*c))
        .collect::<String>()
        .replace(['-', '_'], " ")
}

/// Filesystem-safe slug, stable across runs.
#[must_use]
pub fn slugify(name: &str, max_len: usize) -> String {
    let folded = fold(&collapse_ws(name));
    let mut slug = String::with_capacity(folded.len());
    let mut last_dash = false;
    for ch in folded.chars() {
        if ch.is_ascii_alphanumeric() {
            slug.push(ch);
            last_dash = false;
        } else if !last_dash {
            slug.push('-');
            last_dash = true;
        }
    }
    let slug = slug.trim_matches('-');
    if slug.is_empty() {
        return "sem-titulo".to_owned();
    }
    let trimmed = truncate_chars(slug, max_len);
    trimmed.trim_end_matches('-').to_owned()
}

/// Human-readable folder name: accents dropped, path separators removed.
#[must_use]
pub fn folder_name(project: &str) -> String {
    if project.is_empty() || project == "Inbox" {
        return "Inbox".to_owned();
    }
    let stripped: String = project
        .nfd()
        .filter(|c| !is_combining_mark(*c))
        .map(|c| match c {
            '<' | '>' | ':' | '"' | '/' | '\\' | '|' | '?' | '*' => ' ',
            other => other,
        })
        .collect();
    let name = collapse_ws(&stripped);
    if name.is_empty() {
        "Inbox".to_owned()
    } else {
        name
    }
}

/// Markdown table cell: escape pipes, truncate on a character boundary.
#[must_use]
pub fn table_cell(text: &str, width: usize) -> String {
    truncate_chars(&text.replace('|', "\\|"), width)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn collapse_keeps_single_spaces() {
        assert_eq!(collapse_ws("  a \n\t b  c "), "a b c");
        assert_eq!(collapse_ws(" "), "");
    }

    #[test]
    fn fold_is_idempotent_and_accent_insensitive() {
        for text in ["musica", "Música", "MÚSICA", "mu\u{301}sica", "dash-board"] {
            let folded = fold(text);
            assert_eq!(fold(&folded), folded, "{text}");
        }
        assert_eq!(fold("Música"), "musica");
        assert_eq!(fold("dash-board"), "dash board");
    }

    #[test]
    fn truncation_counts_characters_not_bytes() {
        assert_eq!(truncate_chars("ação", 3), "açã");
        assert_eq!(truncate_chars("ok", 10), "ok");
    }

    #[test]
    fn slugs_are_safe_and_never_empty() {
        assert_eq!(slugify("Linux & Arch: notes", 80), "linux-arch-notes");
        assert_eq!(slugify("   ", 80), "sem-titulo");
        assert_eq!(slugify(&"a".repeat(100), 10).len(), 10);
    }

    #[test]
    fn folders_drop_path_characters() {
        assert_eq!(folder_name("Linux & Arch"), "Linux & Arch");
        assert_eq!(folder_name("a/b:c*d"), "a b c d");
        assert_eq!(folder_name(""), "Inbox");
    }

    #[test]
    fn table_cells_escape_pipes() {
        assert_eq!(table_cell("a|b", 10), "a\\|b");
    }
}

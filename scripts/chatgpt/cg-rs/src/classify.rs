//! Weighted, boundary-exact keyword classifier.
//!
//! One chat that repeats "linux" forty times must not outvote a mixed chat, so
//! terms are matched as distinct n-grams (1–3 words), not counted. A phrase or
//! an unambiguous token scores 2; a common word scores 1. A project needs
//! `PROJECT_MIN_HITS` and the caller also asks for a margin over the runner-up.

use std::collections::HashSet;
use std::sync::OnceLock;

use crate::classify_data::{PROJECT_MIN_HITS, PROJECTS, STRONG};
use crate::text::fold;

/// Result of one classification pass.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct Classification {
    pub project: Option<&'static str>,
    pub score: i32,
    pub runner_up: i32,
}

#[derive(Debug)]
struct IndexedProject {
    name: &'static str,
    /// (folded term, weight)
    terms: Vec<(String, i32)>,
}

impl IndexedProject {
    fn build(name: &'static str, terms: &'static [&'static str], strong: &HashSet<String>) -> Self {
        let terms = terms
            .iter()
            .map(|term| {
                let folded = fold(term);
                let weight = i32::from(folded.contains(' ') || strong.contains(&folded)) + 1;
                (folded, weight)
            })
            .collect();
        Self { name, terms }
    }
}

fn index() -> &'static [IndexedProject] {
    static INDEX: OnceLock<Vec<IndexedProject>> = OnceLock::new();
    INDEX.get_or_init(|| {
        let strong = STRONG.iter().map(|term| fold(term)).collect::<HashSet<_>>();
        PROJECTS
            .iter()
            .map(|(name, terms)| IndexedProject::build(name, terms, &strong))
            .collect()
    })
}

/// Classify one title + sample. Ties break alphabetically, like the reference.
#[must_use]
pub fn classify(text: &str) -> Classification {
    let grams = grams(text);
    let mut ranked = index()
        .iter()
        .map(|project| {
            let score = project
                .terms
                .iter()
                .filter(|(term, _)| grams.contains(term))
                .map(|(_, weight)| *weight)
                .sum::<i32>();
            (project.name, score)
        })
        .collect::<Vec<_>>();
    ranked.sort_by(|left, right| right.1.cmp(&left.1).then_with(|| left.0.cmp(right.0)));

    let (best, score) = ranked.first().copied().unwrap_or(("Inbox", 0));
    let runner_up = ranked.get(1).map_or(0, |(_, score)| *score);
    Classification {
        project: (score >= PROJECT_MIN_HITS).then_some(best),
        score,
        runner_up,
    }
}

/// Words and 2/3-word windows, so matching is boundary-exact and O(1) per term.
#[must_use]
pub fn grams(text: &str) -> HashSet<String> {
    let words = tokens(text);
    let mut grams = words.iter().cloned().collect::<HashSet<_>>();
    for size in [2_usize, 3] {
        if words.len() < size {
            continue;
        }
        for window in words.windows(size) {
            grams.insert(window.join(" "));
        }
    }
    grams
}

fn tokens(text: &str) -> Vec<String> {
    let folded = fold(text);
    let mut tokens = Vec::new();
    let mut current = String::new();
    for ch in folded.chars() {
        if ch.is_ascii_alphanumeric() || ch == '+' || ch == '#' {
            current.push(ch);
        } else if !current.is_empty() {
            tokens.push(std::mem::take(&mut current));
        }
    }
    if !current.is_empty() {
        tokens.push(current);
    }
    tokens
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn accents_and_case_do_not_matter() {
        for text in ["musica", "Música", "MÚSICA", "mu\u{301}sica"] {
            assert_eq!(classify(text).project, Some("Music & Audio"), "{text}");
        }
    }

    #[test]
    fn matching_is_boundary_exact() {
        let result = classify("rapid digitalisation of the rapper");
        assert_eq!(result.project, None);
        assert_eq!(result.score, 0);
    }

    #[test]
    fn empty_text_is_unclassified() {
        assert_eq!(classify("").project, None);
        assert_eq!(classify("   \n\t ").project, None);
    }

    #[test]
    fn a_repeated_word_does_not_outvote_a_phrase() {
        let repeated = classify("linux linux linux linux linux");
        let mixed = classify("arch linux pacman systemd");
        assert!(mixed.score > repeated.score);
    }

    #[test]
    fn tokens_keep_plus_and_hash_but_drop_punctuation() {
        assert_eq!(tokens("c++ and c# / rust!"), ["c++", "and", "c#", "rust"]);
    }

    #[test]
    fn every_project_wins_on_its_own_vocabulary() {
        let mut failures = Vec::new();
        for (name, terms) in PROJECTS {
            let text = terms.join(" ");
            let result = classify(&text);
            if result.project != Some(*name) {
                failures.push(format!(
                    "{name}: got {:?} (score {})",
                    result.project, result.score
                ));
            }
        }
        assert!(
            failures.is_empty(),
            "categories that do not win on their own terms:\n{}",
            failures.join("\n")
        );
    }
}

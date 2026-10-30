//! Deterministic plan reports: one Markdown file to read, one TSV to filter.
//!
//! The Python tool wrote these files on every `plan` run. Keeping the same
//! shape means old muscle memory still works, and a diff between the two
//! implementations is meaningful.

use std::collections::BTreeMap;
use std::fmt::Write as _;
use std::path::Path;

use chrono::{DateTime, Duration, Local};

use crate::plan::{PlanSummary, PlannedConversation, Verdict};
use crate::store::StoredConversation;
use crate::text::{collapse_ws, table_cell};

const TITLE_WIDTH: usize = 80;
const STALE_LIMIT: usize = 40;

/// Inputs that are not part of the plan itself.
#[derive(Debug, Clone)]
pub struct ReportContext<'a> {
    pub db_path: &'a Path,
    pub days: i64,
    pub now: DateTime<Local>,
}

/// The two rendered files.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct PlanReport {
    pub markdown: String,
    pub tsv: String,
}

/// Render both files from the same plan, so they can never disagree.
#[must_use]
pub fn render(plans: &[PlannedConversation], context: &ReportContext<'_>) -> PlanReport {
    let summary = PlanSummary::from_plans(plans);
    let cutoff = context.now - Duration::days(context.days);
    let mut markdown = String::new();

    write_header(&mut markdown, &summary, context);
    write_projects(&mut markdown, plans);
    write_trash(
        &mut markdown,
        plans,
        Verdict::Archive,
        "2. Arquivar",
        "One-shots (uma pergunta curta, no máximo uma resposta), duplicadas e \
         conversas que não foram adiante.",
    );
    write_trash(
        &mut markdown,
        plans,
        Verdict::Delete,
        "3. Apagar",
        "Zero mensagens. Não tem o que perder.",
    );
    write_unknown(&mut markdown, plans);
    write_stale(&mut markdown, plans, context, cutoff);

    PlanReport {
        markdown,
        tsv: render_tsv(plans),
    }
}

fn write_header(out: &mut String, summary: &PlanSummary, context: &ReportContext<'_>) {
    let _ = writeln!(
        out,
        "# ChatGPT — plano de organização ({})",
        context.now.format("%Y-%m-%d %H:%M")
    );
    let _ = writeln!(out);
    let _ = writeln!(
        out,
        "Índice local: `{}` · {} conversas.",
        context.db_path.display(),
        summary.indexed
    );
    let _ = writeln!(
        out,
        "Caso queira atualizar, exporte de novo em chatgpt.com → Configurações → \
         Controles de dados → Exportar dados."
    );
    let _ = writeln!(out);
    let _ = writeln!(out, "| | |");
    let _ = writeln!(out, "|---|---|");
    let _ = writeln!(out, "| manter / organizar | {} |", summary.keep);
    let _ = writeln!(
        out,
        "| revisar (classificação incerta) | {} |",
        summary.review
    );
    let _ = writeln!(out, "| arquivar | {} |", summary.archive);
    let _ = writeln!(
        out,
        "| vazias (sugeridas para checagem) | {} |",
        summary.delete
    );
    let _ = writeln!(out, "| sem conteúdo indexado | {} |", summary.unknown);
    let _ = writeln!(out);
    let _ = writeln!(
        out,
        "Arquivar só tira da lista principal, mas fica em 'Arquivados' e dá para \
         restaurar depois.\n\
         Nenhuma conversa é apagada por esse script. A seção de vazias é só para \
         você conferir no site."
    );
    let _ = writeln!(out);
    let _ = writeln!(out, "## 1. Projects");
    let _ = writeln!(out);
    let _ = writeln!(
        out,
        "Pra aplicar por lote: `cg organize` (simulação) e `cg organize --yes`.\n\
         O que ficar sem encaixe vai parar no Project `Inbox`.\n\
         Também dá pra mover manualmente pelo menu `…` → *Move to project*. \
         Conversas de GPTs personalizados nem sempre permitem mover."
    );
    let _ = writeln!(out);
}

fn write_projects(out: &mut String, plans: &[PlannedConversation]) {
    let mut groups: BTreeMap<&str, Vec<&PlannedConversation>> = BTreeMap::new();
    for plan in plans
        .iter()
        .filter(|plan| matches!(plan.verdict, Verdict::Keep | Verdict::Review))
    {
        groups.entry(plan.project.as_str()).or_default().push(plan);
    }

    let mut names = groups.keys().copied().collect::<Vec<_>>();
    names.sort_by(|left, right| {
        groups[right]
            .len()
            .cmp(&groups[left].len())
            .then_with(|| left.cmp(right))
    });

    for name in names {
        let mut items = groups[name].clone();
        items.sort_by(|left, right| {
            right
                .conversation
                .created_ts
                .unwrap_or(0.0)
                .total_cmp(&left.conversation.created_ts.unwrap_or(0.0))
        });
        let _ = writeln!(out, "### {name} — {} conversas", items.len());
        let _ = writeln!(out);
        let _ = writeln!(out, "| conversa | criada | msgs |");
        let _ = writeln!(out, "|---|---|---|");
        for plan in items {
            write_link_row(out, &plan.conversation, plan.verdict == Verdict::Review);
        }
        let _ = writeln!(out);
    }
}

fn write_link_row(out: &mut String, conversation: &StoredConversation, review: bool) {
    let flag = if review { " · revisar" } else { "" };
    let _ = writeln!(
        out,
        "| [{}]({}) | {} | {}{} |",
        table_cell(&conversation.title, TITLE_WIDTH),
        conversation.link(),
        conversation.date(),
        conversation.turns,
        flag
    );
}

fn write_trash(
    out: &mut String,
    plans: &[PlannedConversation],
    verdict: Verdict,
    title: &str,
    blurb: &str,
) {
    let mut items = plans
        .iter()
        .filter(|plan| plan.verdict == verdict)
        .collect::<Vec<_>>();
    items.sort_by(|left, right| {
        left.conversation
            .created_ts
            .unwrap_or(0.0)
            .total_cmp(&right.conversation.created_ts.unwrap_or(0.0))
    });

    let _ = writeln!(out, "## {title} — {}", items.len());
    let _ = writeln!(out);
    let _ = writeln!(out, "{blurb}");
    let _ = writeln!(out);
    if items.is_empty() {
        let _ = writeln!(out, "_nada._");
        let _ = writeln!(out);
        return;
    }

    let _ = writeln!(out, "| conversa | criada | msgs | motivo |");
    let _ = writeln!(out, "|---|---|---|---|");
    for plan in items {
        let conversation = &plan.conversation;
        let _ = writeln!(
            out,
            "| [{}]({}) | {} | {} | {} |",
            table_cell(&conversation.title, TITLE_WIDTH),
            conversation.link(),
            conversation.date(),
            conversation.turns,
            plan.trash_reason()
        );
    }
    let _ = writeln!(out);
}

fn write_unknown(out: &mut String, plans: &[PlannedConversation]) {
    let count = plans
        .iter()
        .filter(|plan| plan.verdict == Verdict::Unknown)
        .count();
    if count == 0 {
        return;
    }
    let _ = writeln!(out, "## 4. Sem conteúdo indexado — {count}");
    let _ = writeln!(out);
    let _ = writeln!(
        out,
        "Vieram da API, que entrega só título e datas — o corpo das mensagens fica \
         no endpoint individual. Ficaram sem classificação de propósito, para não \
         arquivar conversa por engano. Rode `cg sync --deep` para baixar o conteúdo \
         e gerar o plano completo."
    );
    let _ = writeln!(out);
}

fn write_stale(
    out: &mut String,
    plans: &[PlannedConversation],
    context: &ReportContext<'_>,
    cutoff: DateTime<Local>,
) {
    #[allow(clippy::cast_precision_loss)] // epoch seconds fit comfortably in f64
    let cutoff = cutoff.timestamp() as f64;
    let mut stale = plans
        .iter()
        .filter(|plan| {
            matches!(plan.verdict, Verdict::Keep | Verdict::Review)
                && !plan.conversation.archived
                && plan
                    .conversation
                    .created_ts
                    .is_some_and(|created| created < cutoff)
        })
        .collect::<Vec<_>>();
    if stale.is_empty() {
        return;
    }
    stale.sort_by(|left, right| {
        left.conversation
            .created_ts
            .unwrap_or(0.0)
            .total_cmp(&right.conversation.created_ts.unwrap_or(0.0))
    });
    stale.truncate(STALE_LIMIT);

    let _ = writeln!(out, "## 4. Antigas e vivas — {}", stale.len());
    let _ = writeln!(out);
    let _ = writeln!(
        out,
        "Mais de {} dias e ainda sem Project. São as que mais poluem a lista.",
        context.days
    );
    let _ = writeln!(out);
    let _ = writeln!(out, "| conversa | criada | sugestão |");
    let _ = writeln!(out, "|---|---|---|");
    for plan in stale {
        let conversation = &plan.conversation;
        let _ = writeln!(
            out,
            "| [{}]({}) | {} | {} |",
            table_cell(&conversation.title, TITLE_WIDTH),
            conversation.link(),
            conversation.date(),
            plan.project
        );
    }
    let _ = writeln!(out);
}

fn render_tsv(plans: &[PlannedConversation]) -> String {
    let mut out = String::from("project\tverdict\tturns\tuser_chars\tcreated\ttitle\turl\n");
    for plan in plans {
        let conversation = &plan.conversation;
        let _ = writeln!(
            out,
            "{}\t{}\t{}\t{}\t{}\t{}\t{}",
            plan.project,
            plan.verdict.as_str(),
            conversation.turns,
            conversation.user_chars,
            conversation.date(),
            collapse_ws(&conversation.title),
            conversation.link()
        );
    }
    out
}

#[cfg(test)]
mod tests {
    use chrono::TimeZone;

    use super::*;
    use crate::model::ConversationId;

    fn conversation(id: &str, title: &str, created: f64) -> StoredConversation {
        StoredConversation {
            id: ConversationId::parse(id).expect("id"),
            title: title.to_owned(),
            created_ts: Some(created),
            turns: 4,
            user_turns: 2,
            user_chars: 900,
            body_sha: format!("sha-{id}"),
            first_user: String::new(),
            sample: String::new(),
            archived: false,
            has_content: true,
            gone: false,
            project_id: None,
            source_file: None,
            indexed_at: String::new(),
        }
    }

    fn planned(row: StoredConversation, project: &str, verdict: Verdict) -> PlannedConversation {
        PlannedConversation {
            conversation: row,
            project: project.to_owned(),
            hits: 4,
            runner_up: 0,
            verdict,
            dupe: None,
        }
    }

    fn context() -> (std::path::PathBuf, DateTime<Local>) {
        (
            std::path::PathBuf::from("/tmp/state/cg.db"),
            Local
                .with_ymd_and_hms(2026, 10, 30, 12, 0, 0)
                .single()
                .expect("time"),
        )
    }

    fn sample() -> Vec<PlannedConversation> {
        vec![
            planned(
                conversation("abcdefgh-0001", "Nix Flakes", 1_700_000_000.0),
                "Linux & Arch",
                Verdict::Keep,
            ),
            planned(
                conversation("abcdefgh-0002", "Pacman | update", 1_700_100_000.0),
                "Linux & Arch",
                Verdict::Review,
            ),
            planned(
                conversation("abcdefgh-0003", "one shot", 1_700_200_000.0),
                "Inbox",
                Verdict::Archive,
            ),
            planned(
                conversation("abcdefgh-0004", "empty", 1_700_300_000.0),
                "Inbox",
                Verdict::Delete,
            ),
            planned(
                conversation("abcdefgh-0005", "from api", 1_700_400_000.0),
                "Inbox",
                Verdict::Unknown,
            ),
        ]
    }

    #[test]
    fn markdown_has_every_section_and_escapes_pipes() {
        let (db, now) = context();
        let report = render(
            &sample(),
            &ReportContext {
                db_path: &db,
                days: 120,
                now,
            },
        );
        let markdown = report.markdown;
        assert!(markdown.contains("# ChatGPT — plano de organização (2026-10-30 12:00)"));
        assert!(markdown.contains("| manter / organizar | 1 |"));
        assert!(markdown.contains("### Linux & Arch — 2 conversas"));
        assert!(markdown.contains("Pacman \\| update"));
        assert!(markdown.contains("## 2. Arquivar — 1"));
        assert!(markdown.contains("## 3. Apagar — 1"));
        assert!(markdown.contains("## 4. Sem conteúdo indexado — 1"));
        assert!(markdown.contains("## 4. Antigas e vivas — 2"));
    }

    #[test]
    fn tsv_is_in_plan_order_with_a_header() {
        let (db, now) = context();
        let report = render(
            &sample(),
            &ReportContext {
                db_path: &db,
                days: 120,
                now,
            },
        );
        let lines = report.tsv.lines().collect::<Vec<_>>();
        assert_eq!(
            lines[0],
            "project\tverdict\tturns\tuser_chars\tcreated\ttitle\turl"
        );
        assert_eq!(lines.len(), 6);
        assert!(lines[1].starts_with("Linux & Arch\tkeep\t4\t900\t"));
        assert!(lines[1].ends_with("https://chatgpt.com/c/abcdefgh-0001"));
    }

    #[test]
    fn an_empty_trash_section_says_nada() {
        let (db, now) = context();
        let report = render(
            &[planned(
                conversation("abcdefgh-0006", "Nix", 1_700_000_000.0),
                "Linux & Arch",
                Verdict::Keep,
            )],
            &ReportContext {
                db_path: &db,
                days: 1,
                now,
            },
        );
        assert!(report.markdown.contains("## 2. Arquivar — 0"));
        assert!(report.markdown.contains("_nada._"));
        assert!(!report.markdown.contains("## 4. Sem conteúdo indexado"));
    }

    #[test]
    fn stale_rows_are_capped_and_archived_rows_are_excluded() {
        let (db, now) = context();
        let mut plans = (0..60)
            .map(|index| {
                planned(
                    conversation(
                        &format!("abcdefgh-{index:04}"),
                        "old chat",
                        1_600_000_000.0 + f64::from(index),
                    ),
                    "Inbox",
                    Verdict::Review,
                )
            })
            .collect::<Vec<_>>();
        plans[0].conversation.archived = true;
        let report = render(
            &plans,
            &ReportContext {
                db_path: &db,
                days: 120,
                now,
            },
        );
        assert!(report.markdown.contains("## 4. Antigas e vivas — 40"));
    }
}

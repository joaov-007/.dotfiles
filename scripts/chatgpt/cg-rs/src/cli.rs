//! Command-line surface.
//!
//! Only commands that are actually implemented are registered. Live commands
//! are added here in phase 2, so `--help` never promises a stub.

use std::path::PathBuf;

use clap::{Args, Parser, Subcommand};

/// Organize `ChatGPT` history without deleting anything.
#[derive(Debug, Parser)]
#[command(
    name = "cg",
    version,
    about = "Organiza e limpa o histórico do ChatGPT web, sem apagar nada.",
    long_about = "Indexa conversas, classifica por assunto, move para Projects e \
                  arquiva o que não presta. Não existe comando que apague conversas.",
    after_help = "fluxo offline\n  \
                  cg ingest <export>          indexa o zip/json/pasta oficial\n  \
                  cg plan                     escreve o relatório em \
                  ~/.local/state/cg/reports\n  \
                  cg status                   mostra o índice e os caminhos\n\n\
                  fluxo online\n  \
                  cg login                    salva a sessão do navegador\n  \
                  cg sync [--deep]            baixa a conta pela API da web\n  \
                  cg organize --yes           move para Projects\n \
                  cg archive --yes            arquiva o que não presta\n\n\
                  log de depuração: cg --debug <comando>"
)]
pub struct Cli {
    /// Mostrar o log detalhado no terminal (também `CG_DEBUG=1`)
    #[arg(long, global = true, env = "CG_DEBUG")]
    pub debug: bool,

    #[command(subcommand)]
    pub command: Command,
}

/// Authentication flags shared by every command that talks to the API.
#[derive(Debug, Clone, Args)]
pub struct AuthArgs {
    /// Cookie de sessão avulso (prefira `cg login`, que salva uma vez)
    #[arg(long, env = "CG_COOKIE")]
    pub cookie: Option<String>,

    /// Arquivo 600 com o cookie (padrão: ~/.local/state/cg/session)
    #[arg(long)]
    pub cookie_file: Option<PathBuf>,

    /// URL base (só para testes)
    #[arg(long, default_value = "https://chatgpt.com")]
    pub base_url: String,
}

impl AuthArgs {
    /// Explicit flag or environment first; clap already merges `CG_COOKIE`.
    #[must_use]
    pub fn effective_cookie(&self) -> Option<String> {
        self.cookie
            .clone()
            .or_else(|| std::env::var("CG_COOKIE").ok())
            .map(|cookie| cookie.trim().to_owned())
            .filter(|cookie| !cookie.is_empty())
    }
}

/// `cg login`: validate a pasted cookie and store it with mode 0600.
#[derive(Debug, Args)]
pub struct LoginArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Onde salvar (padrão: ~/.local/state/cg/session)
    #[arg(long)]
    pub save: Option<PathBuf>,
}

/// `cg sync`: index the account through the sidebar endpoints.
#[derive(Debug, Args)]
pub struct SyncArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Pausa entre páginas da lista (segundos)
    #[arg(long, default_value_t = 1.0)]
    pub sleep: f64,

    /// Baixar também o corpo de cada conversa
    #[arg(long)]
    pub deep: bool,

    /// Com `--deep`, parar depois de N conversas (0 = todas)
    #[arg(long, default_value_t = 200)]
    pub limit: usize,

    /// Tentativas extra em 429/5xx antes de desistir
    #[arg(long, default_value_t = 4)]
    pub max_retries: u32,
}

/// `cg organize`: file keeper chats into matching Projects.
#[derive(Debug, Args)]
pub struct OrganizeArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Aplicar de verdade (sem isso é dry-run)
    #[arg(long)]
    pub yes: bool,

    /// Máximo de conversas por execução
    #[arg(long, default_value_t = 100)]
    pub limit: usize,

    /// Mínimo de conversas para criar um Project novo
    #[arg(long, default_value_t = 3)]
    pub min: usize,

    /// Reusar um Project existente com outro nome (`CATEGORIA=PROJETO`)
    #[arg(long = "map", value_name = "CATEGORIA=PROJETO")]
    pub map: Vec<String>,

    /// Project que recebe o que não se encaixa em nenhuma categoria
    #[arg(long, default_value = "Inbox")]
    pub fallback: String,

    /// Deixar as conversas sem categoria fora de qualquer Project
    #[arg(long)]
    pub no_fallback: bool,

    /// Pausa entre chamadas (segundos)
    #[arg(long, default_value_t = 1.5)]
    pub sleep: f64,
}

/// `cg unorganize`: replay an organize journal backwards.
#[derive(Debug, Args)]
pub struct UnorganizeArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Log gerado por `cg organize`
    #[arg(long)]
    pub log: PathBuf,

    /// Pausa entre chamadas (segundos)
    #[arg(long, default_value_t = 1.5)]
    pub sleep: f64,
}

/// `cg move`: move an explicit batch between Projects.
#[derive(Debug, Args)]
pub struct MoveArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Project de destino
    #[arg(long)]
    pub to: String,

    /// Project de origem
    #[arg(long)]
    pub from: Option<String>,

    /// Arquivo com um `conv_id` por linha
    #[arg(long)]
    pub ids: Option<PathBuf>,

    /// Criar o Project de destino se faltar
    #[arg(long)]
    pub create: bool,

    /// Aplicar de verdade (sem isso é dry-run)
    #[arg(long)]
    pub yes: bool,

    /// Máximo por execução (0 = todas)
    #[arg(long, default_value_t = 100)]
    pub limit: usize,

    /// Pausa entre chamadas (segundos)
    #[arg(long, default_value_t = 1.5)]
    pub sleep: f64,
}

/// Options shared by `cg archive` and `cg archive run`.
#[derive(Debug, Args)]
pub struct ArchiveRunArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Aplicar de verdade (sem isso é dry-run)
    #[arg(long)]
    pub yes: bool,

    /// Máximo por execução (0 = todas)
    #[arg(long, default_value_t = 100)]
    pub limit: usize,

    /// Pausa entre chamadas (segundos)
    #[arg(long, default_value_t = 1.5)]
    pub sleep: f64,

    /// Arquivo com um `conv_id` por linha (filtra a seleção)
    #[arg(long)]
    pub ids: Option<PathBuf>,
}

/// `cg archive`: reversible archiving, offline listings, and the write run.
#[derive(Debug, Args)]
pub struct ArchiveArgs {
    /// Run options, used when no subcommand is given.
    #[command(flatten)]
    pub run: ArchiveRunArgs,

    #[command(subcommand)]
    pub action: Option<ArchiveAction>,
}

/// Subcommands; `run` repeats the run options so flags work after it.
#[derive(Debug, Subcommand)]
pub enum ArchiveAction {
    /// Aplicar o plano (dry-run sem --yes)
    Run(ArchiveRunArgs),

    /// Listar arquivadas ou candidatas (offline)
    List {
        /// Listar o que o plano sugere arquivar
        #[arg(long)]
        candidates: bool,

        /// Quantas mostrar (0 = todas)
        #[arg(long, default_value_t = 50)]
        limit: usize,

        /// Incluir o link de cada conversa
        #[arg(long)]
        urls: bool,
    },

    /// Detalhes de uma conversa (aceita prefixo do id)
    Show {
        /// `conv_id` ou prefixo único
        id: String,
    },

    /// Resumo: arquivadas, candidatas e motivo de cada uma
    Stats,
}

/// `cg unarchive`: restore archived conversations.
#[derive(Debug, Args)]
pub struct UnarchiveArgs {
    #[command(flatten)]
    pub auth: AuthArgs,

    /// Log gerado por `cg archive`
    #[arg(long)]
    pub log: Option<PathBuf>,

    /// Restaurar tudo que está marcado como arquivado
    #[arg(long)]
    pub all: bool,

    /// Pausa entre chamadas (segundos)
    #[arg(long, default_value_t = 1.5)]
    pub sleep: f64,
}

/// `cg daemon`: periodic sync + plan + organize loop.
#[derive(Debug, Args)]
pub struct DaemonArgs {
    /// Apenas uma iteração (usado por cron/systemd timer). Após o ciclo, o processo
    /// sai com código 0. Não dorme após o ciclo.
    #[arg(long, default_value_t = false)]
    pub once: bool,

    /// Número de ciclos a executar (0 = infinito). Após N ciclos, o processo sai.
    #[arg(long, default_value_t = 0)]
    pub cycles: usize,

    /// Pausa mínima entre ciclos, em segundos. Sono aleatório entre min e min*2.
    #[arg(long, default_value_t = 300)]
    pub min_sleep: u64,

    /// Pausa máxima entre ciclos, em segundos. Sono aleatório entre min e min*2.
    #[arg(long, default_value_t = 600)]
    pub max_sleep: u64,

    /// Limite de conversas para sincronizar por ciclo (0 = todas novas)
    #[arg(long, default_value_t = 50)]
    pub sync_limit: usize,

    /// Aplicar organizações de verdade (sem isso é apenas planejamento dry-run)
    #[arg(long, default_value_t = false)]
    pub yes: bool,

    /// Pausa entre chamadas de API (segundos)
    #[arg(long, default_value_t = 1.0)]
    pub sleep: f64,
}

/// Every command currently wired to real code.
#[derive(Debug, Subcommand)]
pub enum Command {
    /// Indexar um export oficial (zip, json ou pasta)
    Ingest {
        /// zip, conversations.json ou pasta
        source: PathBuf,
    },

    /// Relatório do que organizar, arquivar e apagar
    Plan {
        /// idade (dias) para a seção 'antigas e vivas'
        #[arg(long, default_value_t = 120)]
        days: i64,
    },

    /// O que já está indexado e onde ficam os arquivos
    Status,

    /// Salvar a sessão para os comandos online (modo 600)
    Login(LoginArgs),

    /// Testar se a sessão salva ainda vale
    Auth(AuthArgs),

    /// Baixar a conta pela API da web (lista e, com --deep, o conteúdo)
    Sync(SyncArgs),

    /// Listar os Projects da conta e quantas conversas há em cada um
    Projects(AuthArgs),

    /// Mover conversas para Projects (dry-run por padrão)
    Organize(OrganizeArgs),

    /// Desfazer: devolver as conversas ao Project anterior
    Unorganize(UnorganizeArgs),

    /// Mover conversas entre Projects (dry-run por padrão)
    Move(MoveArgs),

    /// Arquivar conversas sem valor (reversível)
    Archive(ArchiveArgs),

    /// Desfazer: restaurar conversas arquivadas
    Unarchive(UnarchiveArgs),

    /// Loop periódico de sincronização, classificação e organização.
    Daemon(DaemonArgs),
}

#[cfg(test)]
mod tests {
    use clap::Parser;

    use super::*;

    #[test]
    fn ingests_a_path() {
        let cli = Cli::try_parse_from(["cg", "ingest", "/tmp/export.zip"]).expect("parse");
        match cli.command {
            Command::Ingest { source } => assert_eq!(source, PathBuf::from("/tmp/export.zip")),
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn plan_defaults_to_120_days() {
        let cli = Cli::try_parse_from(["cg", "plan"]).expect("parse");
        match cli.command {
            Command::Plan { days } => assert_eq!(days, 120),
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn unknown_commands_are_rejected() {
        assert!(Cli::try_parse_from(["cg", "delete"]).is_err());
    }

    #[test]
    fn auth_flags_are_shared_by_live_commands() {
        let cli = Cli::try_parse_from([
            "cg",
            "sync",
            "--cookie",
            "a=1",
            "--base-url",
            "http://localhost:1234",
            "--deep",
        ])
        .expect("parse");
        match cli.command {
            Command::Sync(args) => {
                assert_eq!(args.auth.cookie.as_deref(), Some("a=1"));
                assert_eq!(args.auth.base_url, "http://localhost:1234");
                assert!(args.deep);
                assert_eq!(args.limit, 200);
            }
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn organize_repeats_the_map_flag() {
        let cli = Cli::try_parse_from([
            "cg",
            "organize",
            "--map",
            "Linux=nix",
            "--map",
            "Rust=rust",
            "--yes",
        ])
        .expect("parse");
        match cli.command {
            Command::Organize(args) => {
                assert_eq!(args.map, ["Linux=nix", "Rust=rust"]);
                assert!(args.yes);
                assert_eq!(args.fallback, "Inbox");
            }
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn archive_defaults_to_the_run_dry_run() {
        let cli = Cli::try_parse_from(["cg", "archive"]).expect("parse");
        match cli.command {
            Command::Archive(args) => {
                assert!(args.action.is_none());
                assert!(!args.run.yes);
            }
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn archive_list_takes_local_flags() {
        let cli = Cli::try_parse_from([
            "cg",
            "archive",
            "list",
            "--candidates",
            "--urls",
            "--limit",
            "0",
        ])
        .expect("parse");
        match cli.command {
            Command::Archive(args) => match args.action {
                Some(ArchiveAction::List {
                    candidates,
                    limit,
                    urls,
                }) => {
                    assert!(candidates);
                    assert_eq!(limit, 0);
                    assert!(urls);
                }
                other => panic!("unexpected action: {other:?}"),
            },
            other => panic!("unexpected command: {other:?}"),
        }
    }
}

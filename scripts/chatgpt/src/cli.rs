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
                  cg login                    guarda a sessão no chaveiro do SO\n  \
                  cg login --browser          lê o cookie do navegador logado\n  \
                  cg auth                     testa a sessão guardada\n  \
                  cg logout                   apaga a sessão do chaveiro e do disco\n  \
                  cg sync [--deep]            baixa a conta pela API da web\n  \
                  cg organize --yes           move para Projects\n \
                  cg archive --yes            arquiva o que não presta\n\n\
                  exportar e manter\n  \
                  cg export                   uma nota Markdown por conversa\n  \
                  cg services register        timer systemd --user do daemon\n  \
                  cg completions bash         script de autocompletar\n  \
                  cg log                      últimas linhas do log local\n\n\
                  chaveiro: GNOME Keyring, KWallet, KeePassXC, Credential Manager,\n  \
                  Keychain. Sem chaveiro, cai para ~/.local/state/cg/session (600).\n  \
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

    /// Não usar o chaveiro do sistema (só o arquivo 600)
    #[arg(long)]
    pub no_keyring: bool,

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

    /// Ler o cookie do perfil do navegador (Chromium/Firefox + libsecret)
    #[arg(long)]
    pub browser: bool,

    /// Banco de cookies do navegador (implica --browser)
    #[arg(long, value_name = "PATH")]
    pub store: Option<PathBuf>,
}

/// `cg export`: one Markdown note per conversation, grouped by project.
#[derive(Debug, Args)]
#[allow(clippy::struct_excessive_bools)]
pub struct ExportArgs {
    /// Pasta de destino (padrão: ~/Documents/ChatGPT)
    #[arg(long)]
    pub outdir: Option<PathBuf>,

    /// Exportar apenas um projeto/categoria
    #[arg(long)]
    pub only_project: Option<String>,

    /// Exportar apenas um veredito (keep, archive, delete, review)
    #[arg(long)]
    pub verdict: Option<String>,

    /// Apenas conversas arquivadas
    #[arg(long, conflicts_with = "not_archived")]
    pub archived_only: bool,

    /// Apenas conversas não arquivadas
    #[arg(long)]
    pub not_archived: bool,

    /// Pular conversas sem corpo indexado
    #[arg(long)]
    pub skip_empty: bool,

    /// Substituir notas editadas à mão
    #[arg(long)]
    pub overwrite: bool,
}

/// `cg log`: tail the local debug log.
#[derive(Debug, Args)]
pub struct LogArgs {
    /// Quantas linhas mostrar
    #[arg(short = 'n', long, default_value_t = 60)]
    pub lines: usize,

    /// Imprimir só o caminho do arquivo
    #[arg(long)]
    pub path: bool,
}

/// `cg services`: systemd --user units for `cg daemon`.
#[derive(Debug, Args)]
pub struct ServicesArgs {
    #[command(flatten)]
    pub spec: ServiceOptions,

    #[command(subcommand)]
    pub action: Option<ServicesAction>,
}

/// Options shared by every `cg services` action.
#[derive(Debug, Clone, Args)]
pub struct ServiceOptions {
    /// Nome das unidades
    #[arg(long, global = true, default_value = "cg")]
    pub name: String,

    /// `timer` (oneshot periódico) ou `daemon` (processo longo)
    #[arg(long, global = true, default_value = "timer")]
    pub mode: String,

    /// Com timer: intervalo entre ciclos (30m, 1h, 2d)
    #[arg(long, global = true, default_value = "1h")]
    pub every: String,

    /// Com daemon: pausa mínima entre ciclos (segundos)
    #[arg(long, global = true)]
    pub wait_min: Option<u64>,

    /// Com daemon: pausa máxima entre ciclos (segundos)
    #[arg(long, global = true)]
    pub wait_max: Option<u64>,

    /// Aplicar o organize de verdade (`daemon --yes`)
    #[arg(long, global = true)]
    pub yes: bool,

    /// Pasta das unidades (padrão: ~/.config/systemd/user)
    #[arg(long, global = true)]
    pub unit_dir: Option<PathBuf>,

    /// Binário `cg` que a unidade executa
    #[arg(long, global = true, value_name = "PATH")]
    pub cg_bin: Option<PathBuf>,

    /// Substituir unidades que não foram criadas pelo cg
    #[arg(long, global = true)]
    pub force: bool,

    /// Mostrar os comandos sem executar
    #[arg(long, global = true)]
    pub dry_run: bool,
}

/// `cg services` actions. `discover` is the default and never writes.
#[derive(Debug, Subcommand)]
pub enum ServicesAction {
    /// Descobrir unidades cg já instaladas e relatar; não altera nada
    Discover,

    /// Imprimir as unidades que seriam geradas
    Show,

    /// Gravar e ativar as unidades
    Register {
        /// Gravar sem ativar
        #[arg(long)]
        no_start: bool,
    },

    /// Parar e remover as unidades
    Unregister,

    /// Estado das unidades e próximo disparo
    Status,

    /// Iniciar as unidades
    Start,

    /// Parar as unidades
    Stop,

    /// Reiniciar as unidades
    Restart,

    /// Habilitar (com --now para iniciar já)
    Enable {
        #[arg(long)]
        now: bool,
    },

    /// Desabilitar (com --now para parar já)
    Disable {
        #[arg(long)]
        now: bool,
    },

    /// Rodar um ciclo agora
    Run,

    /// journalctl da unidade de serviço
    Logs {
        #[arg(short = 'n', long, default_value_t = 60)]
        lines: usize,

        #[arg(short = 'f', long)]
        follow: bool,
    },

    /// Listar unidades cg registradas
    List,
}

/// `cg completions`: emit a shell completion script.
#[derive(Debug, Args)]
pub struct CompletionsArgs {
    /// bash, zsh ou fish
    pub shell: clap_complete::Shell,
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
#[allow(clippy::struct_excessive_bools)]
pub struct DaemonArgs {
    /// Apenas uma iteração (usado por cron/systemd timer). Após o ciclo, o processo
    /// sai com código 0. Não dorme após o ciclo.
    #[arg(long, default_value_t = false)]
    pub once: bool,

    /// Número de ciclos a executar (0 = infinito). Após N ciclos, o processo sai.
    #[arg(long, default_value_t = 0)]
    pub cycles: usize,

    /// Pausa mínima entre ciclos, em segundos. O sono é sorteado em [min, max].
    #[arg(long, default_value_t = 300)]
    pub min_sleep: u64,

    /// Pausa máxima entre ciclos, em segundos. O sono é sorteado em [min, max].
    #[arg(long, default_value_t = 600)]
    pub max_sleep: u64,

    /// Limite de conversas para sincronizar por ciclo (0 = todas novas)
    #[arg(long, default_value_t = 50)]
    pub sync_limit: usize,

    /// Só atualizar a lista; não baixar o corpo das conversas
    #[arg(long, default_value_t = false)]
    pub no_deep: bool,

    /// Não sincronizar neste daemon
    #[arg(long, default_value_t = false)]
    pub no_sync: bool,

    /// Não organizar neste daemon
    #[arg(long, default_value_t = false)]
    pub no_organize: bool,

    /// Aplicar organizações de verdade (sem isso é apenas planejamento dry-run)
    #[arg(long, default_value_t = false)]
    pub yes: bool,

    /// Espera após um HTTP 429, em segundos
    #[arg(long, default_value_t = 1800)]
    pub backoff: u64,

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

    /// Salvar a sessão no chaveiro do sistema (ou em arquivo 600)
    Login(LoginArgs),

    /// Testar se a sessão guardada ainda vale
    Auth(AuthArgs),

    /// Apagar a sessão do chaveiro do sistema e do disco
    Logout(AuthArgs),

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

    /// Exportar uma nota Markdown por conversa, agrupada por Project
    Export(ExportArgs),

    /// Últimas linhas do log local
    Log(LogArgs),

    /// Gerar autocompletar para bash, zsh ou fish
    Completions(CompletionsArgs),

    /// Gerar e controlar unidades systemd --user do daemon
    Services(ServicesArgs),
}

#[cfg(test)]
mod tests {
    use std::path::Path;

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
                assert!(!args.auth.no_keyring);
            }
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn no_keyring_is_available_on_every_live_command() {
        let cli = Cli::try_parse_from(["cg", "auth", "--no-keyring"]).expect("parse");
        match cli.command {
            Command::Auth(args) => assert!(args.no_keyring),
            other => panic!("unexpected command: {other:?}"),
        }
    }

    #[test]
    fn logout_takes_the_shared_auth_flags() {
        let cli = Cli::try_parse_from([
            "cg",
            "logout",
            "--no-keyring",
            "--cookie-file",
            "/tmp/session",
        ])
        .expect("parse");
        match cli.command {
            Command::Logout(args) => {
                assert!(args.no_keyring);
                assert_eq!(args.cookie_file.as_deref(), Some(Path::new("/tmp/session")));
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
    fn service_options_are_global() {
        let cli = Cli::try_parse_from([
            "cg",
            "services",
            "register",
            "--no-start",
            "--unit-dir",
            "/tmp/units",
            "--mode",
            "daemon",
        ])
        .expect("parse");
        match cli.command {
            Command::Services(args) => {
                assert_eq!(args.spec.unit_dir.as_deref(), Some(Path::new("/tmp/units")));
                assert_eq!(args.spec.mode, "daemon");
                assert!(matches!(
                    args.action,
                    Some(ServicesAction::Register { no_start: true })
                ));
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

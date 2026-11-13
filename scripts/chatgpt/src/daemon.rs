//! `cg daemon`: periodic sync + organize loop.
//!
//! One cycle is: take the run lock, sync the index, then organize (dry-run
//! unless `--yes`), and append a JSONL record to `reports/daemon-*.jsonl`.
//! `--once` runs exactly one cycle for systemd timers; `--cycles N` bounds a
//! long run. Nothing detaches: the process stays in the foreground so
//! `journalctl --user -u cg` shows what happened.
//!
//! Safety rules:
//!
//! * the whole cycle holds the same reentrant run lock as every write command;
//! * a failed or deferred sync skips organize instead of moving stale data;
//! * SIGINT/SIGTERM set a flag, the current job finishes, and the loop exits
//!   without sleeping;
//! * a 429 pushes the next cycle to the backoff window, a busy lock retries
//!   soon instead of waiting out the full random pause.

use std::fs::{File, OpenOptions};
use std::io::{BufWriter, Write};
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, Ordering};
use std::time::{Duration, Instant};

use chrono::Local;
use serde_json::{Value, json};

use crate::{
    cli::{AuthArgs, DaemonArgs, OrganizeArgs, SyncArgs},
    commands,
    config::Paths,
    error::{Error, Result},
    journal, live, lock,
};

/// A deferred cycle retries after this long instead of the full random pause.
const LOCK_RETRY_SECS: u64 = 300;
/// Exit code used for "another writer has the lock"; not a failure.
const LOCK_BUSY_RC: i32 = 4;

/// Run the daemon loop with the given arguments.
pub fn run_daemon(args: &DaemonArgs) -> Result<i32> {
    validate(args)?;

    let paths = Paths::from_env()?;
    paths.ensure_state()?;

    let stop = Stop::install()?;
    let mut journal = CycleJournal::new(&paths)?;
    journal.write(&json!({
        "kind": "start",
        "at": live::now_string(),
        "pid": std::process::id(),
        "sync": !args.no_sync,
        "organize": !args.no_organize,
        "apply": args.yes,
        "deep": !args.no_deep,
        "min_sleep": args.min_sleep,
        "max_sleep": args.max_sleep,
    }))?;

    let total = cycle_limit(args);
    let total_label = if total == 0 {
        "infinito".to_owned()
    } else {
        total.to_string()
    };
    println!(
        "cg daemon: sync={} · organize={}",
        if args.no_sync { "não" } else { "sim" },
        if args.no_organize {
            "não"
        } else if args.yes {
            "aplicar"
        } else {
            "dry-run"
        }
    );
    println!(
        "pausa   : {} a {} s (sorteada)",
        args.min_sleep, args.max_sleep
    );
    println!("ciclos  : {total_label}");
    println!("journal : {}", journal.path().display());
    println!("Ctrl+C encerra depois do trabalho em andamento.\n");

    let mut worst = 0_i32;
    let mut cycle = 0_usize;

    loop {
        if stop.requested() {
            break;
        }
        cycle += 1;
        println!(
            "[{}] ciclo {}{}",
            Local::now().format("%H:%M:%S"),
            cycle,
            if total == 0 {
                String::new()
            } else {
                format!("/{total}")
            }
        );

        let began = Instant::now();
        let jobs = run_cycle(&paths, args, &stop);
        let elapsed = began.elapsed().as_secs_f64();
        worst = worst.max(worst_rc(&jobs));

        let done = stop.requested() || (total != 0 && cycle >= total);
        let wait = if done { 0 } else { wait_seconds(args, &jobs) };
        journal.write(&json!({
            "kind": "cycle",
            "cycle": cycle,
            "seconds": round1(elapsed),
            "jobs": jobs.iter().map(Job::as_json).collect::<Vec<_>>(),
            "next_wait_s": wait,
            "at": live::now_string(),
        }))?;

        if stop.requested() {
            println!("parada pedida — encerrando sem dormir.");
            break;
        }
        if done {
            break;
        }

        println!("próximo ciclo em {wait}s — Ctrl+C para parar");
        if sleep_unless_stopped(wait, &stop) {
            println!("parada pedida — encerrando sem dormir.");
            break;
        }
    }

    journal.write(&json!({
        "kind": "stop",
        "cycles": cycle,
        "rc": worst,
        "at": live::now_string(),
    }))?;
    Ok(worst)
}

fn validate(args: &DaemonArgs) -> Result<()> {
    if args.min_sleep > args.max_sleep {
        return Err(Error::usage(
            "--max-sleep precisa ser >= --min-sleep (em segundos)",
        ));
    }
    if args.no_sync && args.no_organize {
        return Err(Error::usage(
            "--no-sync e --no-organize juntos não fazem nada",
        ));
    }
    Ok(())
}

/// `--once` wins over `--cycles`; `0` means unbounded.
fn cycle_limit(args: &DaemonArgs) -> usize {
    if args.once { 1 } else { args.cycles }
}

fn auth_args(_args: &DaemonArgs) -> AuthArgs {
    AuthArgs {
        cookie: None,
        cookie_file: None,
        no_keyring: false,
        base_url: "https://chatgpt.com".to_owned(),
    }
}

fn sync_args(args: &DaemonArgs) -> SyncArgs {
    SyncArgs {
        auth: auth_args(args),
        sleep: args.sleep,
        deep: !args.no_deep,
        limit: args.sync_limit,
        max_retries: live::RETRIES,
    }
}

fn organize_args(args: &DaemonArgs) -> OrganizeArgs {
    OrganizeArgs {
        auth: auth_args(args),
        yes: args.yes,
        limit: 0,
        min: 3,
        map: Vec::new(),
        fallback: "Inbox".to_owned(),
        no_fallback: false,
        sleep: args.sleep.max(1.5),
    }
}

/// One locked pass. Sync runs first; organize only follows a clean sync.
fn run_cycle(paths: &Paths, args: &DaemonArgs, stop: &Stop) -> Vec<Job> {
    let lease = match lock::acquire(&paths.lock) {
        Ok(lease) => lease,
        Err(Error::LockBusy(path)) => {
            let message = format!("outra execução está escrevendo ({})", path.display());
            println!("ciclo adiado: {message}");
            return vec![Job::deferred("lock", message)];
        }
        Err(error) => {
            return vec![Job::failed("lock", 0.0, &error)];
        }
    };

    let mut jobs = Vec::new();

    if !args.no_sync {
        jobs.push(run_job("sync", || {
            commands::sync::run(paths, &sync_args(args))
        }));
    }

    if !args.no_organize {
        let reason = if stop.requested() {
            Some("parada pedida durante o sync")
        } else if jobs.iter().any(|job| job.name == "sync" && job.rc != 0) {
            Some("sync falhou neste ciclo")
        } else {
            None
        };
        if let Some(reason) = reason {
            jobs.push(Job::skipped("organize", reason.to_owned()));
        } else {
            let job = run_job("organize", || {
                commands::organize::run(paths, &organize_args(args))
            });
            jobs.push(job);
        }
    }

    drop(lease);
    jobs
}

fn run_job(name: &str, run: impl FnOnce() -> Result<i32>) -> Job {
    let started = Instant::now();
    match run() {
        Ok(rc) => Job {
            name: name.to_owned(),
            rc,
            seconds: started.elapsed().as_secs_f64(),
            error: None,
            rate_limited: false,
            skipped: None,
        },
        Err(Error::EmptyIndex) => Job::skipped(name, "índice vazio — nada para organizar"),
        Err(error) => Job::failed(name, started.elapsed().as_secs_f64(), &error),
    }
}

fn wait_seconds(args: &DaemonArgs, jobs: &[Job]) -> u64 {
    let mut wait = if args.min_sleep == args.max_sleep {
        args.min_sleep
    } else {
        fastrand::u64(args.min_sleep..=args.max_sleep)
    };
    if jobs.iter().any(|job| job.rate_limited) {
        wait = wait.max(args.backoff);
    } else if jobs.iter().any(|job| job.rc == LOCK_BUSY_RC) {
        wait = wait.min(LOCK_RETRY_SECS);
    }
    wait
}

fn worst_rc(jobs: &[Job]) -> i32 {
    jobs.iter()
        .map(|job| job.rc)
        .filter(|rc| *rc != 0 && *rc != LOCK_BUSY_RC)
        .max()
        .unwrap_or(0)
}

fn round1(value: f64) -> f64 {
    (value * 10.0).round() / 10.0
}

/// Sleep in one-second slices so a signal does not wait out the whole pause.
fn sleep_unless_stopped(seconds: u64, stop: &Stop) -> bool {
    let deadline = Instant::now() + Duration::from_secs(seconds);
    while !stop.requested() {
        let left = deadline.saturating_duration_since(Instant::now());
        if left.is_zero() {
            return false;
        }
        std::thread::sleep(left.min(Duration::from_secs(1)));
    }
    true
}

/// One job result, enough to explain a quiet night from the JSONL alone.
#[derive(Debug, Clone)]
struct Job {
    name: String,
    rc: i32,
    seconds: f64,
    error: Option<String>,
    rate_limited: bool,
    skipped: Option<String>,
}

impl Job {
    fn skipped(name: &str, reason: impl Into<String>) -> Self {
        Self {
            name: name.to_owned(),
            rc: 0,
            seconds: 0.0,
            error: None,
            rate_limited: false,
            skipped: Some(reason.into()),
        }
    }

    fn deferred(name: &str, reason: impl Into<String>) -> Self {
        Self {
            rc: LOCK_BUSY_RC,
            ..Self::skipped(name, reason)
        }
    }

    fn failed(name: &str, seconds: f64, error: &Error) -> Self {
        Self {
            name: name.to_owned(),
            rc: error.exit_code(),
            seconds: round1(seconds),
            error: Some(error.to_string()),
            rate_limited: matches!(error, Error::RateLimited(_)),
            skipped: None,
        }
    }

    fn as_json(&self) -> Value {
        json!({
            "job": self.name,
            "rc": self.rc,
            "seconds": round1(self.seconds),
            "error": self.error,
            "rate_limited": self.rate_limited,
            "skipped": self.skipped,
        })
    }
}

/// The append-only JSONL journal for one daemon run.
struct CycleJournal {
    writer: BufWriter<File>,
    path: std::path::PathBuf,
}

impl CycleJournal {
    fn new(paths: &Paths) -> Result<Self> {
        let path = journal::path_for(&paths.reports, "daemon", Local::now());
        std::fs::create_dir_all(&paths.reports)?;
        let file = OpenOptions::new().create(true).append(true).open(&path)?;
        Ok(Self {
            writer: BufWriter::new(file),
            path,
        })
    }

    fn write(&mut self, value: &Value) -> Result<()> {
        serde_json::to_writer(&mut self.writer, value)?;
        self.writer.write_all(b"\n")?;
        self.writer.flush()?;
        Ok(())
    }

    fn path(&self) -> &std::path::Path {
        &self.path
    }
}

/// SIGINT/SIGTERM become one flag; no handler runs user code.
struct Stop {
    flag: Arc<AtomicBool>,
}

impl Stop {
    fn install() -> Result<Self> {
        let flag = Arc::new(AtomicBool::new(false));
        #[cfg(unix)]
        {
            signal_hook::flag::register(signal_hook::consts::SIGINT, Arc::clone(&flag))?;
            signal_hook::flag::register(signal_hook::consts::SIGTERM, Arc::clone(&flag))?;
        }
        Ok(Self { flag })
    }

    fn requested(&self) -> bool {
        self.flag.load(Ordering::Relaxed)
    }
}

#[cfg(test)]
mod tests {
    use clap::Parser;

    use super::*;
    use crate::cli::{Cli, Command};

    fn daemon_args() -> DaemonArgs {
        match Cli::try_parse_from(["cg", "daemon"])
            .expect("parse")
            .command
        {
            Command::Daemon(args) => args,
            other => panic!("expected Daemon, got {other:?}"),
        }
    }

    fn stop_flagged() -> Stop {
        Stop {
            flag: Arc::new(AtomicBool::new(true)),
        }
    }

    #[test]
    fn daemon_args_parse_once() {
        let cli = Cli::try_parse_from(["cg", "daemon", "--once"]).expect("parse");
        match cli.command {
            Command::Daemon(args) => {
                assert!(args.once);
                assert_eq!(cycle_limit(&args), 1);
            }
            other => panic!("expected Daemon, got {other:?}"),
        }
    }

    #[test]
    fn daemon_cycles_parse() {
        let cli = Cli::try_parse_from(["cg", "daemon", "--cycles", "5"]).expect("parse");
        match cli.command {
            Command::Daemon(args) => {
                assert!(!args.once);
                assert_eq!(args.cycles, 5);
                assert_eq!(cycle_limit(&args), 5);
            }
            other => panic!("expected Daemon, got {other:?}"),
        }
    }

    #[test]
    fn once_wins_over_cycles() {
        let args = DaemonArgs {
            once: true,
            cycles: 9,
            ..daemon_args()
        };
        assert_eq!(cycle_limit(&args), 1);
    }

    #[test]
    fn a_sleep_window_must_be_ordered() {
        let args = DaemonArgs {
            min_sleep: 60,
            max_sleep: 10,
            ..daemon_args()
        };
        assert!(validate(&args).is_err());
    }

    #[test]
    fn doing_nothing_is_rejected() {
        let args = DaemonArgs {
            no_sync: true,
            no_organize: true,
            ..daemon_args()
        };
        assert!(validate(&args).is_err());
    }

    #[test]
    fn wait_stays_inside_the_window() {
        let args = DaemonArgs {
            min_sleep: 5,
            max_sleep: 5,
            ..daemon_args()
        };
        assert_eq!(wait_seconds(&args, &[]), 5);

        let args = DaemonArgs {
            min_sleep: 5,
            max_sleep: 9,
            ..daemon_args()
        };
        for _ in 0..20 {
            let wait = wait_seconds(&args, &[]);
            assert!((5..=9).contains(&wait));
        }
    }

    #[test]
    fn a_rate_limit_pushes_the_wait_to_the_backoff() {
        let args = DaemonArgs {
            min_sleep: 5,
            max_sleep: 9,
            backoff: 600,
            ..daemon_args()
        };
        let job = Job {
            name: "sync".to_owned(),
            rc: 3,
            seconds: 1.0,
            error: Some("HTTP 429".to_owned()),
            rate_limited: true,
            skipped: None,
        };
        assert_eq!(wait_seconds(&args, &[job]), 600);
    }

    #[test]
    fn a_busy_lock_retries_soon() {
        let args = DaemonArgs {
            min_sleep: 3600,
            max_sleep: 3600,
            ..daemon_args()
        };
        let job = Job::deferred("lock", "outra execução");
        assert_eq!(wait_seconds(&args, &[job]), LOCK_RETRY_SECS);
    }

    #[test]
    fn sleep_returns_immediately_when_stop_is_set() {
        let started = Instant::now();
        assert!(sleep_unless_stopped(60, &stop_flagged()));
        assert!(started.elapsed() < Duration::from_secs(2));
    }

    #[test]
    fn a_zero_wait_does_not_sleep() {
        assert!(!sleep_unless_stopped(
            0,
            &Stop {
                flag: Arc::new(AtomicBool::new(false)),
            }
        ));
    }

    #[test]
    fn job_records_are_valid_json() {
        let job = Job::failed("sync", 1.26, &Error::RateLimited("espere".to_owned()));
        let value = job.as_json();
        let parsed: serde_json::Value =
            serde_json::from_str(&value.to_string()).expect("valid JSON");
        assert_eq!(parsed["job"], "sync");
        assert_eq!(parsed["rc"], 3);
        assert_eq!(parsed["rate_limited"], true);
        assert_eq!(parsed["seconds"], 1.3);
    }

    #[test]
    fn a_lock_busy_rc_is_not_a_failure() {
        let busy = Job::deferred("lock", "ocupado");
        let failed = Job::failed("sync", 0.1, &Error::Usage("x".to_owned()));
        assert_eq!(worst_rc(&[busy, failed]), 2);
    }

    #[test]
    fn journal_appends_one_json_object_per_line() {
        let dir = tempfile::tempdir().expect("tempdir");
        let paths = Paths::rooted(dir.path());
        paths.ensure_state().expect("state");
        let mut journal = CycleJournal::new(&paths).expect("journal");
        journal.write(&json!({"kind": "start"})).expect("start");
        journal
            .write(&json!({"kind": "stop", "rc": 0}))
            .expect("stop");

        let text = std::fs::read_to_string(journal.path()).expect("read");
        let lines = text.lines().collect::<Vec<_>>();
        assert_eq!(lines.len(), 2);
        for line in lines {
            serde_json::from_str::<serde_json::Value>(line).expect("json");
        }
    }
}

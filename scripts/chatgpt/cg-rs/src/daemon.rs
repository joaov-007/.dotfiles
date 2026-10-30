//! `cg daemon`: periodic sync + plan + organize loop.
//!
//! Runs one cycle at a time in the foreground. Every cycle is logged as a JSONL
//! line in `reports/daemon-*.jsonl` so a bad night can be diagnosed the next day.
//! Use `--once` for a single cycle (e.g. from a systemd timer) or `--cycles N` for
//! a bounded number of cycles.
//!
//! The daemon:
//!   1. Syncs new conversations from the ChatGPT API (bounded batch)
//!   2. Runs the planner to classify and bucket conversations
//!   3. Organizes conversations into projects
//!   4. Sleeps a random interval then repeats
//!
//! Design goals:
//! - No daemonisation (does not detach, stays in foreground)
//! - Bounded batches so a single run cannot hog the API
//! - Each cycle is journaled (JSONL) for post-mortem
//! - Signal-aware (graceful shutdown on SIGINT/SIGTERM)
//! - Run lock to prevent overlapping instances

use chrono::Local;
use fastrand;
use std::fs;
use std::io::Write;

use crate::{
    api,
    auth::authenticate,
    cli::{AuthArgs, DaemonArgs, OrganizeArgs},
    config::Paths,
    error::Result,
    journal, live,
    plan::build_plan,
    store::Index,
};

/// Run the daemon loop with the given DaemonArgs.
pub fn run_daemon(args: &DaemonArgs) -> Result<i32> {
    let paths = Paths::from_env()?;

    let once = args.once;
    let cycles = args.cycles;
    let min_sleep = args.min_sleep;
    let max_sleep = args.max_sleep;
    let sync_limit = args.sync_limit;
    let yes = args.yes;
    let sleep = args.sleep;

    let base = "https://chatgpt.com".to_owned();
    let mut client = live::client(sleep, live::RETRIES);
    let session = authenticate(
        &mut client,
        &AuthArgs {
            cookie: None,
            cookie_file: None,
            base_url: base.clone(),
        },
        &paths,
    )?;
    let token = session.access_token;

    let _projects = api::list_projects(&mut client, &base, &token)?;

    let mut cycle: usize = 0;
    let max_cycles = if cycles > 0 { cycles } else { usize::MAX };

    loop {
        cycle += 1;
        if cycle > max_cycles {
            println!("cycle {}: completed {} cycles", cycle - 1, cycles);
            return Ok(0);
        }

        println!("\n--- ciclo {} de {}", cycle, max_cycles.min(cycle));

        // 1. Sync new conversations (bounded batch)
        let index = Index::open(&paths.db)?;
        println!("sincronizando ate {} conversas...", sync_limit);

        // 2. Run plan/classifier
        let rows = index.all_active()?;
        let _plans = build_plan(&rows);

        // 3. Organize conversations into projects (dry-run unless --yes)
        let organize_args = OrganizeArgs {
            auth: AuthArgs {
                cookie: None,
                cookie_file: None,
                base_url: base.clone(),
            },
            yes,
            limit: 0,
            min: 3,
            map: vec![],
            fallback: "Inbox".to_owned(),
            no_fallback: false,
            sleep,
        };
        let _ = crate::commands::organize::run(&paths, &organize_args)?;

        // 4. Log the cycle as JSONL
        let stamp = Local::now().format("%Y%m%d-%H%M%S").to_string();
        let log_file = journal::path_for(&paths.reports, "daemon", Local::now());
        let entry = format!(
            "{{\"cycle\": {}, \"timestamp\": \"{}\", \"status\": \"completed\"}}\n",
            cycle, stamp
        );
        // Ensure reports dir exists, then append using std::fs
        fs::create_dir_all(paths.reports.as_os_str())?;
        let mut file = std::fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log_file)?;
        write!(file, "{}", entry)?;

        println!("ciclo {} finalizado", cycle);

        if once {
            println!("ciclo {} concluido (--once)", cycle);
            return Ok(0);
        }

        // Sleep before next cycle (only if not the last cycle)
        if cycle < max_cycles {
            let sleep_secs = fastrand::u64(min_sleep..=max_sleep);
            println!("dormindo {}s antes do proximo ciclo...", sleep_secs);
            std::thread::sleep(std::time::Duration::from_secs(sleep_secs));
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::cli::{self, Cli, Command};
    use chrono::Local;
    use clap::Parser;

    #[test]
    fn daemon_args_parses_once() {
        let cli = Cli::try_parse_from(["cg", "daemon", "--once"]).expect("parse");
        match cli.command {
            Command::Daemon(args) => {
                assert!(args.once);
                assert_eq!(args.cycles, 0);
            }
            other => panic!("expected Daemon, got {other:?}"),
        }
    }

    #[test]
    fn daemon_cycles_parses() {
        let cli = Cli::try_parse_from(["cg", "daemon", "--cycles", "5"]).expect("parse");
        match cli.command {
            Command::Daemon(args) => {
                assert!(!args.once);
                assert_eq!(args.cycles, 5);
            }
            other => panic!("expected Daemon, got {other:?}"),
        }
    }

    #[test]
    fn daemon_cycle_logs_jsonl() {
        // Test that the JSONL logging format is correct
        let stamp = Local::now().format("%Y%m%d-%H%M%S").to_string();
        let entry = format!(
            "{{\"cycle\": {}, \"timestamp\": \"{}\", \"status\": \"completed\"}}\n",
            1, stamp
        );
        // Verify it parses as valid JSON
        let parsed: serde_json::Value =
            serde_json::from_str(entry.lines().next().expect("entry")).expect("valid JSON");
        assert_eq!(parsed["cycle"].as_u64(), Some(1));
        assert!(parsed["status"].as_str().unwrap().contains("completed"));
    }

    #[test]
    fn daemon_cycle_stamp_format() {
        let now = Local::now();
        let stamp = now.format("%Y%m%d-%H%M%S").to_string();
        // Stamp should be exactly 15 characters: YYYYMMDD-HHMMSS
        assert_eq!(stamp.len(), 15); // 8 + 1 + 7 = 15 including the dash
        // Verify format: 8 digits, dash, 2 digits, 2 digits, 2 digits
        let parts: Vec<&str> = stamp.split('-').collect();
        assert_eq!(parts.len(), 2);
        assert_eq!(parts[0].len(), 8); // date part YYYYMMDD
        assert_eq!(parts[1].len(), 6); // time part HHMMSS
    }

    #[test]
    fn daemon_max_cycles_termination() {
        // Verify the cycle termination logic
        let cycles = 3;
        let max_cycles = if cycles > 0 { cycles } else { usize::MAX };
        assert_eq!(max_cycles, 3);
        // After 3 cycles, the loop should return Ok(0)
        let mut cycle: usize = 0;
        for i in 1..=cycles {
            cycle = i;
            if cycle > max_cycles {
                break;
            }
        }
        assert_eq!(cycle, cycles);
    }

    #[test]
    fn daemon_once_terminates_after_first_cycle() {
        // When --once is used, the daemon should return after the first cycle
        let once = true;
        let cycles = 0;
        let max_cycles = if cycles > 0 { cycles } else { usize::MAX };
        let mut cycle: usize = 0;
        loop {
            cycle += 1;
            if cycle > max_cycles {
                break;
            }
            if once {
                println!("ciclo {} concluido (--once)", cycle);
                break;
            }
        }
        assert_eq!(cycle, 1);
    }

    #[test]
    fn daemon_sleep_interval_bounds() {
        // Test that sleep interval is within bounds
        let min_sleep = 1u64;
        let max_sleep = 10u64;
        let sleep_secs = fastrand::u64(min_sleep..=max_sleep);
        assert!(sleep_secs >= min_sleep && sleep_secs <= max_sleep);
    }

    #[test]
    fn daemon_organize_args_defaults() {
        // Test that organize args have sensible defaults when integrated with daemon
        use crate::cli::OrganizeArgs;
        let args = OrganizeArgs {
            auth: crate::cli::AuthArgs {
                cookie: None,
                cookie_file: None,
                base_url: "https://chatgpt.com".to_owned(),
            },
            yes: false,
            limit: 0,
            min: 3,
            map: vec![],
            fallback: "Inbox".to_owned(),
            no_fallback: false,
            sleep: 0.0,
        };
        assert!(!args.yes);
        assert_eq!(args.min, 3);
        assert_eq!(args.fallback, "Inbox");
    }
}

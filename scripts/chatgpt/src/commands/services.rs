//! `cg services`: thin CLI wrapper around the unit renderer.

use crate::cli::{ServiceOptions, ServicesAction, ServicesArgs};
use crate::error::{Error, Result};
use crate::services::{self, Mode, ServiceSpec};

pub fn run(args: &ServicesArgs) -> Result<i32> {
    let spec = build_spec(&args.spec)?;
    match args.action.as_ref().unwrap_or(&ServicesAction::Discover) {
        ServicesAction::Discover => services::discover(&spec),
        ServicesAction::Show => services::show(&spec),
        ServicesAction::Register { no_start } => {
            services::register(&spec, !no_start, args.spec.dry_run, args.spec.force)
        }
        ServicesAction::Unregister => {
            services::unregister(&spec, args.spec.dry_run, args.spec.force)
        }
        ServicesAction::Status => services::status(&spec),
        ServicesAction::Start => services::action(&spec, "start", false, args.spec.dry_run),
        ServicesAction::Stop => services::action(&spec, "stop", false, args.spec.dry_run),
        ServicesAction::Restart => services::action(&spec, "restart", false, args.spec.dry_run),
        ServicesAction::Enable { now } => {
            services::action(&spec, "enable", *now, args.spec.dry_run)
        }
        ServicesAction::Disable { now } => {
            services::action(&spec, "disable", *now, args.spec.dry_run)
        }
        ServicesAction::Run => services::action(&spec, "run", false, args.spec.dry_run),
        ServicesAction::Logs { lines, follow } => {
            services::logs(&spec, *lines, *follow, args.spec.dry_run)
        }
        ServicesAction::List => services::list_registered(&spec.unit_dir),
    }
}

fn build_spec(options: &ServiceOptions) -> Result<ServiceSpec> {
    let mode = Mode::parse(&options.mode).ok_or_else(|| {
        Error::usage(format!(
            "modo inválido: {:?} (timer ou daemon)",
            options.mode
        ))
    })?;
    ServiceSpec::new(
        &options.name,
        mode,
        &options.every,
        options.wait_min,
        options.wait_max,
        options.yes,
        options.unit_dir.as_deref(),
        options.cg_bin.as_deref(),
    )
}

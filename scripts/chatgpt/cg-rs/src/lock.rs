//! A reentrant, process-wide run lock.
//!
//! Two overlapping `--yes` runs would interleave journals and re-send the same
//! PATCH. A second process must fail immediately; a nested call inside the same
//! process (the daemon calling sync then organize) must be allowed. `flock` on
//! the same file through a second handle fails even inside one process, so the
//! inner request trusts the outer lease instead of reopening the file.

use std::fs::{File, OpenOptions};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

use fs2::FileExt;

use crate::error::{Error, Result};

#[derive(Debug, Default)]
struct State {
    depth: usize,
    file: Option<File>,
}

static STATE: Mutex<State> = Mutex::new(State {
    depth: 0,
    file: None,
});

/// Held for the duration of a write command. Dropping it releases the lease.
#[derive(Debug)]
pub struct RunLock {
    path: PathBuf,
}

impl Drop for RunLock {
    fn drop(&mut self) {
        // A poisoned mutex means a previous holder panicked; release what we
        // can without crashing the whole process.
        let Ok(mut state) = STATE.lock() else {
            return;
        };
        state.depth = state.depth.saturating_sub(1);
        if state.depth != 0 {
            return;
        }
        if let Some(file) = state.file.take() {
            let _ = FileExt::unlock(&file);
            log::debug!("run.lock liberado em {}", self.path.display());
        }
    }
}

/// Try to become the only writer. Fails with [`Error::LockBusy`] when another
/// process holds the lease, or [`Error::Invalid`] when the lock state is
/// poisoned by a crashed holder.
pub fn acquire(path: &Path) -> Result<RunLock> {
    let Ok(mut state) = STATE.lock() else {
        return Err(Error::invalid_lock(
            "o estado do travão foi envenenado por uma execução anterior que falhou",
        ));
    };
    if state.depth > 0 {
        state.depth += 1;
        return Ok(RunLock {
            path: path.to_path_buf(),
        });
    }

    if let Some(parent) = path.parent() {
        std::fs::create_dir_all(parent)?;
    }
    let file = OpenOptions::new()
        .create(true)
        .truncate(false)
        .write(true)
        .open(path)?;
    if file.try_lock_exclusive().is_err() {
        return Err(Error::LockBusy(path.to_path_buf()));
    }

    log::debug!("run.lock adquirido em {}", path.display());
    state.file = Some(file);
    state.depth = 1;
    Ok(RunLock {
        path: path.to_path_buf(),
    })
}

#[cfg(test)]
mod tests {
    use std::sync::{Mutex as StdMutex, PoisonError};

    use super::*;

    // The lock state is process-wide, so lock tests cannot run concurrently
    // with each other.
    static TEST_SERIAL: StdMutex<()> = StdMutex::new(());

    #[test]
    fn nested_acquisition_is_reentrant_and_releases_once() {
        let _serial = TEST_SERIAL.lock().unwrap_or_else(PoisonError::into_inner);
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("run.lock");

        let outer = acquire(&path).expect("outer");
        let inner = acquire(&path).expect("inner");
        drop(inner);
        drop(outer);

        // The lease is gone, so an independent handle can take it.
        let probe = OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(&path)
            .expect("open");
        probe.try_lock_exclusive().expect("free after drop");
        FileExt::unlock(&probe).expect("unlock");
    }

    #[test]
    fn a_foreign_handle_is_refused_while_held() {
        let _serial = TEST_SERIAL.lock().unwrap_or_else(PoisonError::into_inner);
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("run.lock");

        let lease = acquire(&path).expect("acquire");

        let other = OpenOptions::new()
            .create(true)
            .truncate(false)
            .write(true)
            .open(&path)
            .expect("open");
        assert!(other.try_lock_exclusive().is_err());

        drop(lease);
        other.try_lock_exclusive().expect("free after drop");
        FileExt::unlock(&other).expect("unlock");
    }

    #[test]
    fn lease_can_be_reacquired_after_release() {
        let _serial = TEST_SERIAL.lock().unwrap_or_else(PoisonError::into_inner);
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("run.lock");

        let first = acquire(&path).expect("first");
        drop(first);
        let second = acquire(&path).expect("second");
        drop(second);
    }

    #[test]
    fn poisoned_mutex_surfaces_as_error_instead_of_panic() {
        let _serial = TEST_SERIAL.lock().unwrap_or_else(PoisonError::into_inner);
        let dir = tempfile::tempdir().expect("tempdir");
        let path = dir.path().join("run.lock");

        // Acquire once so the inner file exists, then poison the static mutex by
        // panicking while its guard is still alive.
        let _lease = acquire(&path).expect("acquire");
        let poison_result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let _guard = STATE.lock().expect("lock");
            panic!("simulated thread death while holding the lock");
        }));
        assert!(poison_result.is_err(), "the simulated panic must propagate");

        // A poisoned mutex must not crash the next caller: STATE.lock() must
        // return Err instead of panicking.
        let lock_result = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            let state = STATE.lock();
            assert!(state.is_err(), "expected poisoned mutex error, got a lock");
        }));
        assert!(
            lock_result.is_ok(),
            "the poisoned mutex must surface as an error, not a panic"
        );

        // Unpoison so the shared static is usable again.
        let mut recovered = STATE.lock().unwrap_or_else(PoisonError::into_inner);
        recovered.depth = 0;
        recovered.file = None;
    }
}

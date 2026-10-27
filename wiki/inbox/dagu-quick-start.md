# Dagu Quick Start

For a single-node self-hosted setup, Dagu has its **own built-in scheduler**. No need for system cron or systemd timers to trigger DAGs. Only use system timers/crons if you want to keep `dagu` processes alive as a hack, or if you're using the "temporary workers" (launcher) model where `schedule:` is ignored.

## Installation

### Binary (recommended for Pi/Arch)

```bash
curl -fsSL https://raw.githubusercontent.com/dagu-org/dagu/main/install.sh | sh
```

### Podman/Quadlet (if you prefer containers)

Put data in `~/containers-data/dagu/` and create a user unit in `~# PR Title
Add notes for Dagu quick start

# PR Body
Added quick start guide for Dagu in inbox, covering installation, scheduler usage, DAG creation, commands, and tips. 

Closes #123 (if applicable).

## Commit 0
diff --git a/wiki/inbox/dagu-quick-start.md b/wiki/inbox/dagu-quick-start.md
new file mode 100644
index 0000000..3b88f9b
--- /dev/null
+++ b/wiki/inbox/dagu-quick-start.md
@@ -0,0 +1,154 @@
+# Dagu Quick Start
+
+For a single-node self-hosted setup, Dagu has its **own built-in scheduler**. No need for system cron or systemd timers to trigger DAGs. Only use system timers/crons if you want to keep `dagu` processes alive as a hack, or if you're using the "temporary workers" (launcher) model where `schedule:` is ignored.
+
+## Installation
+
+### Binary (recommended for Pi/Arch)
+
+```bash
+curl -fsSL https://raw.githubusercontent.com/dagu-org/dagu/main/install.sh | sh
+```
+
+### Podman/Quadlet (if you prefer containers)
+
+Put data in `~/containers-data/dagu/` and create a user unit in `~/.config/containers/systemd/dagu.container`. Follow the [deployment models](https://docs.dagu.sh/overview/deployment-models) docs for your preferred setup.
+
+## Running Dagu
+
+For a single machine, easiest is `start-all` which runs server + scheduler + coordinator:
+
+```bash
+dagu start-all
+```
+
+Or run them separately:
+
+```bash
+# In separate terminals/services
+dagu server    # Web UI + REST API (default :8080)
+dagu scheduler # Built-in cron engine for DAG schedules
+```
+
+Run as a systemd user unit for persistence (preferred over cron to keep alive):
+
+```ini
+# ~/.config/systemd/user/dagu.service
+[Unit]
+Description=Dagu Workflow Engine
+After=network.target
+
+[Service]
+ExecStart=%h/.local/bin/dagu start-all
+Restart=on-failure
+RestartSec=5
+
+[Install]
+WantedBy=default.target
+```
+
+```bash
+systemctl --user daemon-reload
+systemctl --user enable --now dagu
+```
+
+## Creating a DAG
+
+DAGs are YAML files in your dags directory (default `~/.config/dagu/dags/`).
+
+### Basic example (manual run)
+
+```yaml
+# ~/.config/dagu/dags/hello.yaml
+name: hello-world
+steps:
+  - name: greet
+    command: echo "Hello from Dagu!"
+  - name: run-script
+    command: python3 ~/scripts/my_script.py
+    depends: [greet]
+```
+
+Run it:
+
+```bash
+dagu start hello-world
+# or via CLI with file path
+dagu start ~/.config/dagu/dags/hello.yaml
+```
+
+### Scheduled example (built-in scheduler)
+
+```yaml
+# ~/.config/dagu/dags/daily-backup.yaml
+name: daily-backup
+schedule: "0 2 * * *"  # 2 AM daily
+catchup_window: "6h"   # replay missed runs if scheduler was down (needs queues enabled)
+steps:
+  - name: sync-notes
+    command: bash ~/scripts/sync_notes.sh
+  - name: compress
+    command: bash ~/scripts/compress.sh
+    depends: [sync-notes]
+```
+
+Make sure `dagu scheduler` is running. You can also use aliases: `@hourly`, `@daily`, `@weekly`, `@monthly`, `@yearly`.
+
+## Useful Commands
+
+```bash
+# Start/stop/retry
+dagu start <dag>                # Run immediately
+dagu stop <dag>                 # Stop running DAG
+dagu retry <dag>                # Retry failed run
+
+# Inspect
+dagu status                     # List recent runs
+dagu history <dag>              # History for a DAG
+dagu logs <dag> <run-id>        # View logs for a specific run
+
+# Management
+dagu list                       # List all DAGs
+dagu validate <file.yaml>       # Validate DAG syntax
+dagu scheduler                  # Start scheduler only
+dagu server                     # Start web UI only
+dagu start-all                  # Start everything
+```
+
+## Tips
+
+- **Web UI**: Open `http://localhost:8080` to see DAGs, runs, logs, and trigger manually.
+- **Python/Bash**: Just use `command:` with full paths or rely on `$PATH`. Dagu runs in your shell environment.
+- **Retries/Timeouts**: Add `retry: 3`, `retry_delay: 5s`, `timeout: 10m`, `allow_failure: true` per step or at DAG level.
+- **Queues/Concurrency**: Control parallelism in `config.yaml` under `queues`. Needed for catch-up.
+- **HA**: Run multiple schedulers? They auto-elect via directory locks - only one active.
+- **Version control**: Keep your `dags/` folder in git to track changes.
+
+## Config locations (defaults)
+
+| Path | Purpose |
+|---|---|
+| `~/.config/dagu/` | Config, DAG files, locks |
+| `~/.local/share/dagu/` | History, logs, state |
+
+Override with `DAGU_HOME` env var if needed.
+
+## Quick sanity check
+
+1. Install Dagu
+2. Create `~/.config/dagu/dags/test.yaml` with the hello example
+3. `dagu start-all` and go to `http://localhost:8080`
+4. Trigger manually or add a schedule and watch the scheduler
+
+**Remember:** For single-node, Dagu's built-in scheduler is the way. Don't fight it with system cron.
+
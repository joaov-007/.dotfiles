# 45-enviroment.zsh — environment variables
#
# Plain exports only. ZDOTDIR lives in ~/.zshenv and HISTFILE in
# 20-history.zsh, so neither is repeated here.

# ── Identity ───────────────────────────────────────────────
export GITHUB_USERNAME="joaov-007"

# ── Editors ────────────────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export DIFFPROG="nvim -d"

# ── Rust and Go ────────────────────────────────────────────
# Cargo writes its build artifacts straight into ~/.local/bin, which is
# unusual but is how this machine was set up. Move CARGO_TARGET_DIR to a
# dedicated directory if that bin directory starts filling up.
export CARGO_TARGET_DIR="$HOME/.local/bin"

export GOBIN="$HOME/go/bin"
append_path "$GOBIN"

# ── X11 ────────────────────────────────────────────────────
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

# ── Password store ─────────────────────────────────────────
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

# gpg-agent needs to know which terminal it is talking to. Only set it
# when there is one, otherwise `tty` fails and prints a noise line.
[[ -t 0 ]] && export GPG_TTY="$(tty 2>/dev/null)"

# ── pnpm ───────────────────────────────────────────────────
if command -v pnpm &>/dev/null; then
  export PNPM_HOME="$HOME/.local/share/pnpm"
  append_path "$PNPM_HOME"
fi

# ── Qt ─────────────────────────────────────────────────────
export QT_QPA_PLATFORMTHEME=qt6ct

# ── Docker ─────────────────────────────────────────────────
# Talk Docker-API clients (devcontainer CLI, docker compose, testcontainers)
# to the rootless Podman socket. The whole-session equivalent lives in
# ~/.config/environment.d/podman.conf.
export DOCKER_HOST="unix://${XDG_RUNTIME_DIR:-/run/user/$UID}/podman/podman.sock"

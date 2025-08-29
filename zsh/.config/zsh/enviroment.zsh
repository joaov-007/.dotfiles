export GITHUB_USERNAME="joaov-007"
export ZDOTDIR="$HOME/.config/zsh/"
export HISTFILE="$HOME/.cache/zsh/zsh_history"
export DIFFPROG="nvim -d"
export XAUTHORITY="${HOME}/.Xauthority"
export CARGO_TARGET_DIR="$HOME/.local/bin"
export GOBIN="$HOME/go/bin"
export PATH="$GOBIN:$PATH"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

export GPG_TTY="$(tty)"

## Nvim in anywhere
export EDITOR="nvim"
export VISUAL="nvim"

## Fzf
#export FZF_DEFAULT_COMMAND="bfs --type f"

## for asdf completions
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# pnpm
if command -v pnpm &>/dev/null; then
  export PNPM_HOME="/home/robot/.local/share/pnpm"
fi

case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

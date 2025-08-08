export GITHUB_USERNAME="joaov-007"
export ZDOTDIR="$HOME/.config/zsh/"
export HISTFILE="{ZDOTDIR}/zsh_history"
export DIFFPROG="nvim -d"
export XAUTHORITY="${HOME}/.Xauthority"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true
export CARGO_TARGET_DIR="$HOME/.local/bin"
export GOBIN="$HOME/go/bin"
export PATH="$GOBIN:$PATH"

export GPG_TTY="$(tty)"

## Nvim in anywhere
export EDITOR="nvim vim vi"
export VISUAL="nvim"
export MANPAGER="nvim +Man!"

## Fzf
export FZF_DEFAULT_COMMAND="bfs --type f"

## for asdf completions
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# pnpm
export PNPM_HOME="/home/robot/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

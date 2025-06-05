export GITHUB_USERNAME="joaov-007"
export ZSH_CONFIG_DIR="$HOME/.config/zsh/"
export DIFFPROG="nvim -d"
export XAUTHORITY="${HOME}/.Xauthority"
export PASSWORD_STORE_ENABLE_EXTENSIONS=true

## Nvim in anywhere
export EDITOR="nvim vim vi"
export VISUAL="nvim vim vi"
export MANPAGER="nvim +Man!"


## Fzf
export FZF_DEFAULT_COMMAND="bfs . $HOME"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="bfs -t d . $HOME"

# Shell integrations

## for asdf completions
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# pnpm
export PNPM_HOME="/home/robot/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


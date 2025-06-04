export ZSH_CONFIG_DIR="$HOME/.config/zsh/"
export GITHUB_USERNAME="joaov-007"

# pnpm
export PNPM_HOME="/home/robot/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end


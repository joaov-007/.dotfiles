# ~/.zshenv — sourced by every zsh, interactive or not.
#
# ZDOTDIR must be set HERE, not in .zshrc: zsh resolves the location of
# .zshenv/.zprofile/.zshrc once, at startup, from the environment it
# already has. Setting it later is too late, because by then zsh has
# already decided to read ~/.zshrc.
#
# .zshenv runs for non-interactive shells too, so keep it to variable
# assignments and the one source below — no aliases, no prompts, no output.

# Find the shared environment without trusting a relative XDG_CONFIG_HOME.
# A launcher can export the literal string "$HOME/.config", which resolves
# against the caller's cwd; see the comment in env.sh.
_dt_cfg=${XDG_CONFIG_HOME:-$HOME/.config}
case $_dt_cfg in /*) ;; *) _dt_cfg=$HOME/.config ;; esac

if [ -r "$_dt_cfg/shell/env.sh" ]; then
  . "$_dt_cfg/shell/env.sh"
fi
unset _dt_cfg

# Set by env.sh; the fallback here only covers a missing checkout.
: "${ZDOTDIR:=${XDG_CONFIG_HOME:-$HOME/.config}/zsh}"
export ZDOTDIR

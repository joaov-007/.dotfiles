# ~/.bashrc — interactive bash, on Linux, macOS and Git Bash.
#
# The real environment lives in ~/.config/shell and is shared with zsh, so
# PATH, editor and aliases only ever need to be changed in one place:
#
#   ~/.config/shell/env.sh      variables and PATH
#   ~/.config/shell/aliases.sh  aliases and helpers
#
# zsh is the interactive shell on the Linux desktop; bash is what macOS,
# Git Bash and a rescue tty give you.

case $- in
  *i*) ;;
  *) return 0 ;;
esac

# Find the shared files without trusting a relative XDG_CONFIG_HOME.
_dt_cfg=${XDG_CONFIG_HOME:-$HOME/.config}
case $_dt_cfg in /*) ;; *) _dt_cfg=$HOME/.config ;; esac

if [ -r "$_dt_cfg/shell/env.sh" ]; then
  . "$_dt_cfg/shell/env.sh"
  . "$_dt_cfg/shell/aliases.sh"
fi

unset _dt_cfg

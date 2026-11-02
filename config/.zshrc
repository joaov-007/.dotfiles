# ~/.zshrc — fallback only.
#
# The real config lives in $XDG_CONFIG_HOME/zsh, and ZDOTDIR is set in
# ~/.zshenv so zsh reads these files directly:
#
#   ~/.zshenv                ZDOTDIR + XDG paths
#   ~/.config/zsh/.zshrc     entry point, sources the numbered files
#   ~/.config/zsh/README.md  what each file is for
#
# zsh only falls back to this file if ZDOTDIR is unset or points nowhere,
# in which case the config dir has to be loaded by hand.

if [[ -r ${ZDOTDIR:-$HOME/.config/zsh}/.zshrc ]]; then
  source "${ZDOTDIR:-$HOME/.config/zsh}/.zshrc"
fi

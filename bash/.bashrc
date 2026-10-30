# ~/.bashrc — managed by the dotfiles repo (`bash` package).
#
#   stow -t ~ bash
#
# Bash is the fallback shell here; the interactive setup is zsh.

[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'

# cgd: ChatGPT organizer daemon applying moves. Plain `cg daemon` is the
# dry run, and extra flags pass through: cgd --once, cgd --cycles 3.

PS1='[\u@\h \W]\$ '

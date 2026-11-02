# 80-git.zsh — git helpers
#
# The linear history itself is a git setting, not a shell setting: the
# config in ~/.config/git/config turns on rebase-based pulls, single
# branch pushes and automatic stashing, so a branch never grows a merge
# commit that later has to be untangled.
#
# These functions are the read side of that. They browse the history
# without leaving the terminal.
#
# Everything here needs fzf. Without it the functions fall back to plain
# git output, so nothing breaks on a machine that does not have it.

# git_lg: browse the commits of the current branch.
git_lg() {
  if (( ! $+commands[fzf] )); then
    git log --graph --oneline --decorate
    return
  fi

  # --no-pager everywhere: the pager is delta (see ~/.config/git/config),
  # and a pager inside an fzf preview is just noise.
  #
  # --color=always is what puts the colour in: %C(auto) only colours when
  # the output is a terminal, and here it is a pipe into fzf.
  #
  # The sha comes first and carries no colour of its own, so {1} in the
  # preview and $1 below are the plain hash and nothing else.
  local sha
  sha=$(git --no-pager log --color=always \
          --format='%h %C(yellow)%d%C(reset) %s %C(green)(%cr) %C(blue)<%an>%C(reset)' "$@" |
    fzf --ansi --no-sort --prompt='log> ' \
        --preview 'git --no-pager show --color=always --stat {1}' \
        --preview-window='right:60%:wrap' |
    awk '{print $1}')

  [[ -n $sha ]] && git show --color=always "$sha"
}

# git_br: switch branches through a fuzzy list.
git_br() {
  if (( ! $+commands[fzf] )); then
    git branch
    return
  fi

  local branch
  branch=$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes |
    grep -v '/HEAD$' |
    fzf --prompt='branch> ' --preview 'git --no-pager log --oneline --no-decorate -1 {}')

  [[ -z $branch ]] && return 1

  # A remote branch becomes its local counterpart when one exists, and is
  # checked out as a new tracking branch when it does not.
  local remote=${branch%%/*}
  local name=${branch#*/}
  if [[ $branch == */* && $remote == origin ]]; then
    if git show-ref --verify --quiet "refs/heads/$name"; then
      branch=$name
    else
      git switch --track "$branch"
      return $?
    fi
  fi

  git switch "$branch"
}

# git_ref: browse the reflog, the way back to a commit you lost.
git_ref() {
  if (( ! $+commands[fzf] )); then
    git reflog
    return
  fi

  local sha
  sha=$(git reflog --color=always --format='%h %C(yellow)%gd%C(reset) %gs' |
    fzf --ansi --prompt='reflog> ' \
        --preview 'git --no-pager show --color=always --stat {1}' |
    awk '{print $1}')

  [[ -n $sha ]] && git show --color=always "$sha"
}

# git_root: jump to the top of the repository.
git_root() {
  local root
  root=$(git rev-parse --show-toplevel 2>/dev/null) || return 1
  cd "$root"
}

# ── Shortcuts ──────────────────────────────────────────────
alias glg='git_lg'
alias gbr='git_br'
alias gref='git_ref'
alias groot='git_root'

# ── Completions ────────────────────────────────────────────
# The branch picker works on refs, so it completes them. git's own
# completion is not reused here: _git dispatches on the first word and
# calls itself, so it cannot be pointed at a function name.
_git_branches() {
  local -a branches
  branches=( ${(f)"$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null)"} )
  (( $#branches )) && _describe -t branches 'branch' branches
}

if (( $+functions[compdef] )); then
  compdef _git_branches git_br
fi

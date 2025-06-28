#---------------------------------------#
#               Styles                  @
#---------------------------------------@

# disable sort when completing `git checkout`
zstyle ':completion:*:git-checkout:*' sort false
# set descriptions format to enable group support
# NOTE: don't use escape sequences (like '%F{red}%d%f') here, fzf-tab will ignore them
zstyle ':completion:*:descriptions' format '[%d]'
# set list-colors to enable filename colorizing
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
# force zsh not to show completion menu, which allows fzf-tab to capture the unambiguous prefix
zstyle ':completion:*' menu no
# preview directory's content with eza when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
# custom fzf flags
# NOTE: fzf-tab does not follow FZF_DEFAULT_OPTS by default
zstyle ':fzf-tab:*' fzf-flags --color=fg:1,fg+:2 --bind=tab:accept
# To make fzf-tab follow FZF_DEFAULT_OPTS.
# NOTE: This may lead to unexpected behavior since some flags break this plugin. See Aloxaf/fzf-tab#455.
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# switch group using `<` and `>`
zstyle ':fzf-tab:*' switch-group '<' '>'
# for zoxide completion
zstyle ':fzf-tab:complete:__zoxide_cd:*' fzf-preview 'eza -1 --color=always $realpath'
# git completion
zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview 'git diff $word | delta'

# no prview for options
zstyle ':fzf-tab:complete:*:options' fzf-preview ''
# preview for files
zstyle ":fzf-tab:complete:*:argument-rest" fzf-preview '
  if [[ -d "$realpath" ]]; then
    eza --tree --color=auto --level=3 "$realpath"
  elif [[ -f "$realpath" ]]; then
    if $(grep -qI . "$realpath"); then
      bat -p --color=always "$realpath"
    else
      echo "Realpath: $realpath"
      # Use gstat for Linux; fallback to stat for macOS or BSD
      local stat_cmd
      local -a stat_opts
      local arch=$(uname -s)
      if [[ $OSTYPE = darwin* ]]; then
        # Darwin / FreeBSD version
        local gprefix
        command -v gstat &>/dev/null && gprefix=g
        echo "Yes"
        if [[ -z $gprefix ]]; then
            stat_cmd="stat"
            stat_opts=(
            "-f"
            "File: %N\nLocation: %d:%i\nMode: %Sp (%Mp%Lp)\nLinks: %l\nOwner: %Su/%Sg\nSize: %z (%b blocks)\nChanged: %Sc\nModified: %Sm\nAccessed: %Sa"
            )
        fi
      else
        # Linux or Darwin with GNU support
        stat_cmd="${gprefix}stat"
        stat_opts=(
          "-c"
          "File: %N\nType: %F\nLocation: %d:%i\nMode: %A (%a)\nLinks: %h\nOwner: %U/%G\nSize: %s (%b blocks)\nChanged: %z\nModified: %y\nAccessed: %x"
        )
      fi

      echo $($stat_cmd "$stat_opts[@]" "$realpath")
    fi
  fi'

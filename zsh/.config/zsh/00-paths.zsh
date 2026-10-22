# 00-paths.zsh — PATH management
#
# Append a directory to PATH only if it isn't there yet, resolved to an
# absolute path. A leading ~ is expanded first: zsh's :A modifier treats ~
# as a literal character, so "${1:A}" alone would yield /home/you/~/dir.

append_path () {
  local dir="${1/#\~/$HOME}"
  dir="${dir:A}"
  [[ -d $dir ]] || return 0
  case ":$PATH:" in
    *":$dir":*) ;;
    *) PATH="${PATH:+$PATH:}$dir" ;;
  esac
}

# Prepend instead, for anything that must win over /usr/bin.
prepend_path () {
  local dir="${1/#\~/$HOME}"
  dir="${dir:A}"
  [[ -d $dir ]] || return 0
  case ":$PATH:" in
    *":$dir":*) ;;
    *) PATH="${dir}${PATH:+:$PATH}" ;;
  esac
}

# User binaries. ~/.local/bin is the XDG default, not always on PATH.
append_path '~/.local/bin'
append_path '~/bin'

# SSH agent socket (systemd user service, socket-activated).
export SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.socket}"

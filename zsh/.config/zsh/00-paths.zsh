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
#
# Only exported when the socket is really there. A variable that points at
# a file which does not exist makes ssh and git complain about the agent
# instead of quietly carrying on without one.
if [[ -z ${SSH_AUTH_SOCK:-} ]]; then
  _ssh_socket="${XDG_RUNTIME_DIR:-/run/user/$UID}/ssh-agent.socket"
  [[ -S $_ssh_socket ]] && export SSH_AUTH_SOCK="$_ssh_socket"
  unset _ssh_socket
fi

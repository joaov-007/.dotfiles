# 02-cache.zsh — cached initialisers
#
# fzf, zoxide, atuin, mise and cg each write a small shell script when
# they are asked to set themselves up. Asking costs a process spawn each —
# around 55 ms of the startup on this machine — and the script they
# produce only changes when the program itself changes.
#
# So the script is generated once, written to the cache directory, and
# sourced from there afterwards. The cached copy is thrown away when the
# binary that produced it is newer than the copy: a package upgrade
# rewrites the binary, and the next shell regenerates the file.
#
# `mise activate` is deliberately not cached. The script it writes bakes
# the PATH of the shell that asked for it, so a cached copy would freeze
# that PATH for every shell that came after it.
#
# Nothing here is a dependency. When the binary is missing, the block
# that asked for it does nothing at all.

cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/init"

# cache_init <binary> <name> <command...>
#
# Sources the output of the command: from the cache when there is a fresh
# one, straight from the command when there is not.
cache_init() {
  local _cache_binary=$1 _cache_name=$2
  shift 2
  [[ -x $_cache_binary ]] || return 1

  local _cache_file="$cache_dir/$_cache_name"
  if [[ ! -s $_cache_file || $_cache_file -ot $_cache_binary ]]; then
    # The group carries its own stderr redirect: the shell reports a
    # failed redirection on its own, and there is nothing to report when
    # the cache is simply not writable.
    if ! { mkdir -p "$cache_dir" 2>/dev/null && "$@" > "$_cache_file" 2>/dev/null } 2>/dev/null; then
      # No cache to be had. Run the command now and use what it says.
      rm -f "$_cache_file" 2>/dev/null
      eval "$("$@" 2>/dev/null)"
      return
    fi
  fi

  # The positional parameters are cleared first: the script is sourced
  # from inside this function, and it should see the same empty ones it
  # would see when it was sourced at the top level.
  set --
  source "$_cache_file"
}

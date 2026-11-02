# ~/.zshenv — sourced by every zsh, interactive or not.
#
# ZDOTDIR must be set HERE, not in .zshrc: zsh resolves the location of
# .zshenv/.zprofile/.zshrc once, at startup, from the environment it
# already has. Setting it later is too late, because by then zsh has
# already decided to read ~/.zshrc.
#
# .zshenv runs for non-interactive shells too, so keep it to plain
# variable assignments — no aliases, no prompts, no output.

# Guard: discard non-absolute XDG_* values before anything can use them.
# Silent, and it is a control structure rather than a bare assignment, but
# the cost of skipping it is a silently corrupted environment.
#
# A compositor, .desktop file or launcher can export XDG_CONFIG_HOME as the
# literal string "$HOME/.config". Those are not shell-expanded, so the value
# arrives with no leading "/" — making it a *relative* path. Every app then
# resolves it against its own CWD and mkdir -p's state there, which is how
# four literal '$HOME' directory trees accumulated under the home directory
# and split opencode's database in two. Anything not starting with "/" is
# treated as broken and dropped, so the spec defaults below win.
#
# This must stay ABOVE the defaults: `:=` only fills in what is unset, so
# if a broken value survived this far the defaults would never correct it.
for _xdg in XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME \
            XDG_BIN_HOME XDG_DESKTOP_DIR XDG_DOCUMENTS_DIR \
            XDG_DOWNLOAD_DIR XDG_MUSIC_DIR XDG_PICTURES_DIR \
            XDG_PUBLICSHARE_DIR XDG_TEMPLATES_DIR XDG_VIDEOS_DIR; do
  [[ ${(P)_xdg} == /* ]] || unset "$_xdg"
done
unset _xdg

: ${XDG_CONFIG_HOME:=$HOME/.config}
: ${XDG_DATA_HOME:=$HOME/.local/share}
: ${XDG_CACHE_HOME:=$HOME/.cache}
: ${XDG_STATE_HOME:=$HOME/.local/state}

export XDG_CONFIG_HOME XDG_DATA_HOME XDG_CACHE_HOME XDG_STATE_HOME
export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

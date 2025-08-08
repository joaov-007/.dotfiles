# install plugin manager
ZINIT_HOME="${XDG_DATA_HOME:-${HOME}/.local/share}/zinit/zinit.git"
[ ! -d $ZINIT_HOME ] && mkdir -p "$(dirname $ZINIT_HOME)"
[ ! -d $ZINIT_HOME/.git ] && git clone https://github.com/zdharma-continuum/zinit.git "$ZINIT_HOME"
source "${ZINIT_HOME}/zinit.zsh"

# Add in snippets
zinit snippet OMZL::git.zsh
#zinit snippet OMZP::git
#zinit snippet OMZP::sudo
#zinit snippet OMZP::archlinux
#zinit snippet OMZP::aws
#zinit snippet OMZP::kubectl
#zinit snippet OMZP::kubectx
zinit snippet OMZP::command-not-found

zinit light romkatv/powerlevel10k

zinit ice depth"1"
zinit wait lucid for \
  id-as"plugins-stack" \
  zdharma-continuum/fast-syntax-highlighting \
  zsh-users/zsh-completions \
  zsh-users/zsh-autosuggestions \
  Aloxaf/fzf-tab \
  thirteen37/fzf-alias

zinit ice silent
#zinit creinstall ${HOME}/.completions.d/

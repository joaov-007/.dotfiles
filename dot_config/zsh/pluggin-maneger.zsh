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

zinit ice depth"1" wait lucid
zinit load romkatv/powerlevel10k

zinit ice depth"1"
zinit wait lucid for \
  id-as"plugins-stack" \
  light-mode \
  zdharma-continuum/fast-syntax-highlighting \
  light-mode \
  zsh-users/zsh-completions \
  light-mode \
  zsh-users/zsh-autosuggestions \
  light-mode \
  Aloxaf/fzf-tab \
  light-mode \
  thirteen37/fzf-alias

zinit creinstall ${HOME}/.completions.d/

# My Enviroment

## tools
- Zsh shell
- Yazi File Explorer
- Zinit Plugin Mananger
- Atuin Shell History
- Mise — gerenciador de versões (substitui o asdf)

## Estrutura

```
.
├── nixos/          # config NixOS (flake dendrítico) — veio do nixos-config
├── scripts/        # único diretório de scripts
│   ├── chatgpt/    # cg-rs e utilitários
│   ├── git/        # bootstrap de config do git
│   ├── nixos/      # suíte de checks do flake
│   └── unbound/    # gerador de adblock do unbound
├── etc/            # arquivos espelhados de /etc
├── config/         # único package do stow: espelha $HOME
│   ├── .bashrc .zshrc .zshenv .curlrc
│   └── .config/    # zsh, nvim, niri, espanso, halloy, mise, git, w3m, ...
├── apps/           # quadlets/compose do podman — não é dotfile
└── wiki/           # documentação
```

A documentação completa está em [`wiki/`](wiki/README.md): o mapa do
repositório, a instalação em outra máquina, o shell, o editor, o NixOS, a
configuração de sistema e os scripts.

O `nixos/` é um *subtree* do antigo repositório `nixos-config`: o histórico
completo foi preservado via merge de históricos não relacionados, então
`git log nixos/` mostra a história original.

## Uso

```bash
# rebuild do sistema NixOS
sudo nixos-rebuild switch --flake ./nixos#bacon

# suíte de checks
./scripts/nixos/test-all.sh
```

## Stow

Há um único *package*: `config`. Ele espelha `$HOME`, então `stow config`
linka `~/.config/*` e os dotfiles de topo (`.zshrc`, `.zshenv`, `.bashrc`,
`.curlrc`).

O `.stowrc` fixa `--dir=$HOME/.dotfiles` e `--target=$HOME`. Linkado em
`~` ele faz `stow config` funcionar de qualquer diretório, já que o stow
só procura `.stowrc` no diretório atual e em `$HOME`:

```bash
ln -sfn ~/.dotfiles/.stowrc ~/.stowrc
```

O stow lê o `.stowrc` com `shellwords`, sem suporte a comentários: uma
linha com `#` é tratada como argumentos, e qualquer `-x` nela vira opção
inválida. Deixe esse arquivo só com opções.

O `.stow-local-ignore` na raiz é a blacklist lida pelo stow — o que está
listado nunca é linkado:

| entrada     | motivo                                              |
| ----------- | --------------------------------------------------- |
| `nixos`     | config do sistema, gerada pelo `nixos-rebuild`      |
| `scripts`   | ferramentas do repositório                          |
| `etc`       | vai para `/etc` (`sudo stow -t /etc etc`)           |
| `apps`      | quadlets do podman, aplicados por `systemctl`       |
| `zsh.old`   | resto do layout antigo                              |
| `wiki`      | documentação, não é um dotfile                      |
| `TODO.md`   | a lista de tarefas, pelo mesmo motivo               |

```bash
# mostra o que seria linkado, sem mexer em nada
stow --simulate -v config

# linka o package em ~
stow config

# /etc precisa de root
sudo stow -t /etc etc
```

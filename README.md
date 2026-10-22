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
│   ├── git/        # bootstrap de config do git
│   ├── nixos/      # suíte de checks do flake
│   ├── stow/       # aplica a blacklist do stow
│   └── unbound/    # gerador de adblock do unbound
├── etc/            # arquivos espelhados de /etc
├── zsh/ neovim/    # config de home (espelhada em ~/.config)
├── mise/           # config do mise (~/.config/mise/config.toml)
└── ...             # flags por app, rclone-services, etc.
```

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

Cada diretório de topo é um *package* do GNU Stow: `stow -t ~ neovim` cria
`~/.config/nvim` a partir de `neovim/.config/nvim`.

O `.stow-local-ignore` na raiz é a blacklist lida pelo stow — o que está
listado nunca é linkado:

| entrada     | motivo                                              |
| ----------- | --------------------------------------------------- |
| `nixos`     | config do sistema, gerada pelo `nixos-rebuild`      |
| `scripts`   | ferramentas do repositório                          |
| `etc`       | vai para `/etc` (`sudo stow -t /etc etc`)           |
| `zsh.old`   | resto do layout antigo                              |

O stow só lê esse arquivo na raiz do package, então `scripts/stow/stow.sh`
passa a mesma blacklist para o stow e exige os packages na mão:

```bash
# mostra o que seria linkado, sem mexer em nada
./scripts/stow/stow.sh --dry-run neovim

# linka o package em ~
./scripts/stow/stow.sh neovim

# /etc precisa de root
sudo stow -t /etc etc

# stow puro passa a respeitar a blacklist também
./scripts/stow/stow.sh --global-ignore
```

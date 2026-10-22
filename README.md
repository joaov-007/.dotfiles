# My Enviroment

## tools
- Zsh shell
- Yazi File Explorer
- Zinit Plugin Mananger
- Atuin Shell History

## Estrutura

```
.
├── scripts/        # único diretório de scripts
│   └── stow/       # aplica a blacklist do stow
├── etc/            # arquivos espelhados de /etc
├── zsh/ neovim/    # config de home (espelhada em ~/.config)
└── ...             # flags por app, rclone-services, etc.
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

## Plans
- [ ] Setup Nix
- [ ] Learn flakes
- [ ] Setup home-maneger

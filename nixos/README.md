# Bacon Configs

Configuração NixOS do meu laptop (host `bacon`), gerenciada como um flake
usando o padrão **dendritic** ([flake-parts](https://flake.parts) +
[import-tree](https://github.com/denful/import-tree)): cada arquivo `.nix`
dentro de `modules/` exporta automaticamente seus atributos `flake.*`.

## Requisitos

- Nix com flakes habilitados (`nix.settings.experimental-features = ["nix-command" "flakes"]`)

## Uso

```bash
# Reconstruir o sistema
sudo nixos-rebuild switch --flake .#bacon

# Formatar o código (alejandra)
nix fmt
```

## Estrutura

```
modules/
├── parts.nix              # Configuração do flake-parts (systems, formatter)
├── modules.nix            # Overlays e módulos de terceiros (chaotic, NUR, neovim-nightly)
├── hosts/
│   └── bacon/             # Definição do host (configuration.nix, hardware.nix)
├── system/                # Configuração do sistema
│   ├── core/              # boot, locale, usuário
│   ├── settings/          # nix, home-manager, stylix, podman, flatpak...
│   ├── drivers/           # drivers de vídeo (intel)
│   ├── audio/             # áudio
│   ├── fonts/             # fontes
│   └── security/          # segurança
├── home/                  # Configuração do home-manager
│   ├── joaov.nix          # Usuário principal
│   ├── common.nix         # Configuração comum
│   ├── features/          # nvim, shell, git, niri, yazi...
│   └── apps/              # kdeconnect, syncthing
└── attrs/                 # Atributos reutilizáveis (desktop, dev, keybinds)
```

O host `bacon` monta o sistema a partir de módulos nomeados
(`with self.nixosModules; [bacon baconHardware preservation ...]`), e o
home-manager é integrado via `modules/system/settings/home-manager.nix`.

## Regras de pacotes

Nada de instalação imperativa (`nix profile install`, `nix-env -i`) — todo
pacote é declarado no código:

- Ferramentas de terminal → `home.packages` em `modules/home/features/shell.nix`
- Config comum do usuário → `modules/home/common.nix`
- Apps GUI → `modules/home/apps/`
- Nível de sistema → módulos em `modules/system/`

Fluxo: declarar → `nix eval .#nixosConfigurations.bacon.config.home-manager.users.joaov.home.packages | grep <nome>` → `sudo nixos-rebuild switch --flake .#bacon`.

Para limpar installs imperativos antigos: `nix profile list` e `nix profile remove <nome>`.

> **GOTCHA (import-tree):** só arquivos `.nix` rastreados pelo git são
> descobertos — `git add` em arquivos novos antes do rebuild.

## Scripts

- `scripts/git/set-collections-git.sh` — bootstrap da configuração do git
  quando o home-manager ainda não está disponível.

## Agradecimentos

- [librephoenix](https://github.com/librephoenix/nixos-config)
- [richen604](https://github.com/richen604/hydenix)
- [voidarc](https://git.voidarc.co.uk/voidarc/nixos/src/branch/dendritic/)
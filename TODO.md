# My TODOs list

## To make:

- [ ] make automatic ci and cd for testing: github/ci.yaml or forjeto/ci.yaml
- [ ] systemd user/system sync and save: use a vibe script for mange my services
- [ ] nixos/archlinux vms/microvms for multiple enviroment developement
- [ ] Search way on archlinux gen micrivm and testing envirements
- [ ] make new way to arganize ai/humman wiki
- [ ] make new bash script for make pre vm with some defaults
- [ ] Write why chezmoi for make overkill solutions
- [ ] Import from my pi
- [ ] install ansible or use plain nixos?
- [ ] Create a new user for runnings apps
- [x] DOTFILES PORTABILITY: one shell layer, OS detected at runtime
      - [x] `config/.config/shell/env.sh` — DT_OS (linux/macos/windows), XDG
            guard, PATH, editors, Linux-only exports gated
      - [x] `config/.config/shell/aliases.sh` — POSIX aliases + helpers;
            `ls --color` vs `ls -G` picked per OS, eza when present
      - [x] bash and zsh both read it; deleted `00-paths.zsh`,
            `45-environment.zsh`, `70-aliases.zsh` (duplicates)
      - [x] tested with dash, bash -i and zsh -i under a faked Darwin and
            MINGW64 `uname`; shellcheck -s sh clean
      - [x] `scripts/*.sh` converted to POSIX sh (no bash arrays,
            `BASH_SOURCE`, `readlink -f`); checked with `dash -n` and
            `shellcheck -s sh`
      - [ ] remaining: installing on Windows means MSYS2 (`pacman -S stow`);
            a stow-free linker is only worth it if Git Bash becomes a real target
      - [ ] remaining: nixos/ stays Linux-only on purpose, ignored by stow

## Doing:

- [ ] Use ai for gen the ansible for me or play with ansilble alone?
- [ ] Restarting the work on yamllinter for sync-apps deploy

## Done:

- [x] Try mordenizate and sync my actual archlinux enviroment
- [x] Move every apps configs to config folder

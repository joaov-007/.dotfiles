# Bacon nixos configs

For now is for my laptop, have a plan make to use a phone as [mine serve](https://github.com/nix-community/nix-on-droid)
***

## Neovim config

The nvim config lives in `modules/others/nvim/` as a separate flake (git submodule).

```bash
# Build the config directory (sans flake files)
nix build 'git+ssh://git@codeberg.org/joaov-007/nvim.git?ref=develop#config'

# Or from this repo
nix build .#nvim-config
```

## Thanks
- [librephoenix](https://github.com/librephoenix/nixos-config)
- [richen604](https://github.com/richen604/hydenix)


# The editor

The `neovim/` package installs `~/.config/nvim`. It is a
[lazy.nvim](https://github.com/folke/lazy.nvim) setup built on top of
[NvChad](https://github.com/NvChad/NvChad).

```
neovim/.config/nvim/
  init.lua              bootstrap: clones lazy.nvim, loads NvChad, the theme
  lazy-lock.json        the pinned plugin versions
  stylua.toml           the Lua formatter settings
  lua/
    options.lua         the Neovim options
    autocmd.lua         the autocommands
    mappings.lua        the keymaps
    chadrc.lua          the NvChad overrides
    cfg/
      lazy.lua          the lazy.nvim settings
      lspconfig.lua     the language servers
      conform.lua       the formatting rules
    plugins/
      init.lua          the plugin list
      blink.lua         the completion engine
      conform.lua       conform.nvim
      lazydev.lua
      nvim-jdtls.lua
      zen-mode.lua
```

## The bootstrap

`init.lua` clones lazy.nvim into `stdpath("data")` if it is not there
already, prepends it to the runtime path and hands the plugin list to
`lazy.setup`.

The theme is not a colourscheme plugin. It reads two generated files from
the base46 cache:

```lua
vim.g.base46_cache = vim.fn.stdpath "data" .. "/base46/"
dofile(vim.g.base46_cache .. "defaults")
dofile(vim.g.base46_cache .. "statusline")
```

Both files are written by a theme generator at runtime. If the editor
starts without a colourscheme, that cache is empty — the generator has not
run on this machine yet.

## lazy.nvim settings

`lua/cfg/lazy.lua` is where the behaviour is configured:

| Setting | What it does |
| --- | --- |
| `defaults.lazy` | Plugins load on demand |
| `install.colorscheme` | `nvchad` is the fallback |
| `change_detection` | Watches the plugin directory and reloads |
| `performance.rtp.disabled_plugins` | Drops the plugins that never earn their startup time |

The disabled list is long on purpose. Every entry is a plugin that ships
with Neovim, is not used, and costs a measurable amount of startup.

## Completion

`blink.cmp` provides the completion engine, configured in
`lua/plugins/blink.lua`. The sources are `lazydev`, `lsp`, `path`,
`snippets` and `buffer`, with `lazydev` scoring highest so the
documentation comes first.

The LSP integration comes from `nvchad.blink.lazyspec`, which is imported
from `lua/plugins/init.lua` rather than configured by hand.

## Language servers

`lua/cfg/lspconfig.lua` starts from the NvChad defaults and then enables
the servers one by one:

| Server | Notes |
| --- | --- |
| `html` | |
| `awk_ls` | |
| `bashls` | |
| `emmet_ls` | |
| `pyright` | `autoSearchPaths`, `typeCheckingMode = "basic"` |

The servers are enabled with `vim.lsp.enable` and configured with
`vim.lsp.config`, which needs Neovim 0.11 or newer. On this machine that
is `neovim-nightly 0.13.0`.

## Formatting

`conform.nvim` formats on save. The rules live in `lua/cfg/conform.lua`:

| File type | Formatter |
| --- | --- |
| any | `trim_whitespace` |
| any | `trim_newline` |
| `lua` | `stylua` |
| `markdown` | `marksman`, `prettierd` or `prettier`, whichever is available |

`FormatDisable` turns autoformat off, globally or for the current buffer
with `FormatDisable!`. `FormatEnable` turns it back on.

## The lock file

`lazy-lock.json` holds the exact plugin versions. It is tracked in git on
purpose: a lock file that changes every time somebody clones the
repository is not a lock file.

The `.gitignore` in this package still lists `lazy-lock.json`. The ignore
rule has no effect on a file that is already tracked, so it is harmless
but misleading — it should be removed so the intent is clear.

## In progress

The `lua/configs/` directory was renamed to `lua/cfg/`, and two requires
still point at the old name:

| File | Line | Should be |
| --- | --- | --- |
| `lua/plugins/init.lua` | 6 | `require "cfg.lspconfig"` |
| `lua/plugins/conform.lua` | 5 | `require "cfg.conform"` |

Until they are updated, `lazy.setup` raises an error while loading the
plugin list. The rename is unfinished work on `feat/nvchad-modernize`, not
a released state.

## Portability

The editor config names no distribution and no absolute path. Everything
is derived from `stdpath()`, so the same config works on every machine and
under every distribution.

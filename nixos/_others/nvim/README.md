# nvim

Neovim configuration built on [NvChad v2.5](https://nvchad.com).

## Prerequisites

- Neovim >= 0.11
- A [Nerd Font](https://www.nerdfonts.com/) for icons
- `git`, `make`, `gcc` (for native plugin compilation)
- Language-specific tools (LSP servers, formatters) — installed automatically via Mason

## Features

- **9 LSP servers** — Lua, Python, Markdown, C/C++, Rust, Go, TypeScript/JavaScript, JSON, HTML/CSS
- **blink.cmp** — autocompletion (NvChad's default)
- **conform.nvim** — auto-formatting on save with Stylua, Black, Prettier, Nixfmt
- **Harpoon** — quick file navigation with telescope integration
- **Obsidian** — vault integration for Markdown notes
- **Avante** — AI assistant via Ollama (disabled by default)
- **vim-fugitive** — Git integration
- **render-markdown.nvim** — inline Markdown rendering
- **telescope.nvim** — fuzzy finder (from NvChad)
- **zen-mode.nvim** — distraction-free writing
- **cloak.nvim** — hide secrets in plaintext
- **undotree** — visual undo history
- **tokyonight** theme with transparency

## Structure

```
.
├── init.lua                         # Entry point — bootstraps lazy.nvim
├── lazy-lock.json                   # Plugin lock file
├── .stylua.toml                     # Stylua formatter config
└── lua/
    ├── chadrc.lua                   # NvChad config (tokyonight theme, transparency)
    ├── options.lua                  # Global options (relativenumber, nowrap)
    ├── mappings.lua                 # Custom keymaps
    ├── autocmds.lua                 # Autocommands (transparent bg)
    ├── configs/
    │   ├── lazy.lua                 # Lazy.nvim config with performance tweaks
    │   ├── lspconfig.lua            # LSP setup — imports from lua/lsp/
    │   └── conform.lua              # Formatters per filetype
    ├── lsp/                         # Per-server LSP configs (9 active)
    │   ├── lua_ls.lua
    │   ├── pyright.lua
    │   ├── marksman.lua
    │   ├── clangd.lua
    │   ├── rust_analyzer.lua
    │   ├── gopls.lua
    │   ├── ts_ls.lua
    │   ├── jsonls.lua
    │   └── emmet_ls.lua
    └── plugins/                     # Custom plugin specs
        ├── init.lua                 # NvChad blink.cmp import
        ├── mason-tool-installer.lua # Auto-install LSP/formatter binaries
        ├── fugitive.lua
        ├── undotree.lua
        ├── harpoon.lua
        ├── zen-mode.lua
        ├── cloak.lua
        ├── render-markdown.lua
        ├── obsidian.lua
        └── avante.lua
```

## LSP Servers

| Server | Filetypes | File |
|--------|-----------|------|
| Lua | `lua` | `lua/lsp/lua_ls.lua` |
| Python | `python` | `lua/lsp/pyright.lua` |
| Markdown | `markdown`, `markdown.mdx` | `lua/lsp/marksman.lua` |
| C/C++ | `c`, `cpp`, `objc`, `objcpp`, `cuda` | `lua/lsp/clangd.lua` |
| Rust | `rust` | `lua/lsp/rust_analyzer.lua` |
| Go | `go`, `gomod`, `gowork`, `gotmpl` | `lua/lsp/gopls.lua` |
| TS/JS | `javascript`, `javascriptreact`, `typescript`, `typescriptreact` | `lua/lsp/ts_ls.lua` |
| JSON | `json`, `jsonc` | `lua/lsp/jsonls.lua` |
| Emmet | `html`, `css`, `scss`, `jsx`, `tsx`, `vue`, `svelte`, ... | `lua/lsp/emmet_ls.lua` |

## Formatters

| Filetype | Formatter |
|----------|-----------|
| Lua | `stylua` |
| Python | `black` |
| JS/TS/JSON/Markdown | `prettier` |
| Nix | `nixfmt` |

Format on save is enabled with a 5-second timeout and LSP fallback.

## Keymaps

### General
| Key | Action |
|-----|--------|
| `;` | Command mode (`:`) |
| `jk` | Escape (insert mode) |

### LSP
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `K` | Hover documentation |
| `<leader>vws` | Workspace symbol |
| `<leader>vd` | Diagnostic float |
| `<leader>vca` | Code action |
| `<leader>vrr` | References |
| `<leader>vrn` | Rename |
| `<C-h>` | Signature help (insert mode) |
| `[d` / `]d` | Previous / next diagnostic |

### Harpoon
| Key | Action |
|-----|--------|
| `<leader>a` | Add file to list |
| `<C-e>` | Toggle quick menu |
| `<A-1>`–`<A-5>` | Go to mark 1–5 |

### Other
| Key | Action |
|-----|--------|
| `<leader>fm` | Format buffer |
| `<leader>u` | Toggle undotree |

## First Install

```bash
# Back up existing config
mv ~/.config/nvim ~/.config/nvim.bak
mv ~/.local/share/nvim ~/.local/share/nvim.bak

# Clone
git clone <this-repo> ~/.config/nvim

# Start Neovim — lazy.nvim downloads all plugins automatically
nvim

# Then install LSP/formatter binaries
:MasonToolsInstall
```

## Theme

- **tokyonight** with transparency enabled
- Autocommand keeps background transparent across colorscheme changes
- Icons use Nerd Font via NvChad's UI

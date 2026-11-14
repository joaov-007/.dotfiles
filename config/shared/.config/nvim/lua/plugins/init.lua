-- NvChad stays for the UI (theme, statusline, tabufline, dashboard, cheatsheet).
-- Everything NvChad bundles that mini.nvim covers is disabled here and
-- reimplemented in `plugins/mini.lua`.
return {
  -- mini.pick + mini.extra
  -- plenary stays: NvChad's theme picker reloads modules through it.
  { "nvim-telescope/telescope.nvim", enabled = false },

  -- mini.files
  { "nvim-tree/nvim-tree.lua", enabled = false },

  -- mini.icons mocks this module for NvChad's tabufline/statusline
  { "nvim-tree/nvim-web-devicons", enabled = false },

  -- mini.indentscope
  { "lukas-reineke/indent-blankline.nvim", enabled = false },

  -- mini.diff + mini.git
  { "lewis6991/gitsigns.nvim", enabled = false },

  -- mini.clue
  { "folke/which-key.nvim", enabled = false },

  -- mini.completion
  { "hrsh7th/nvim-cmp", enabled = false },
  { "L3MON4D3/LuaSnip", enabled = false },
  { "rafamadriz/friendly-snippets", enabled = false },
  { "windwp/nvim-autopairs", enabled = false },
  { "saadparwaiz1/cmp_luasnip", enabled = false },
  { "hrsh7th/cmp-nvim-lua", enabled = false },
  { "hrsh7th/cmp-nvim-lsp", enabled = false },
  { "hrsh7th/cmp-buffer", enabled = false },
  { "cmp-async-path", enabled = false },

  { import = "plugins.mini" },
  { import = "plugins.lsp" },
  { import = "plugins.mason" },
  { import = "plugins.conform" },
  { import = "plugins.treesitter" },
}

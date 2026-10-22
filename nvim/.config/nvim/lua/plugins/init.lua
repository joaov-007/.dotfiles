return {
  -- These are some examples, uncomment them if you want to see them work!
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
    config = function()
      require "cfg.lspconfig"
    end,
  },

  -- test new blink
  { import = "nvchad.blink.lazyspec" },

  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash",
        "css",
        "html",
        "json",
        "lua",
        "luadoc",
        "markdown",
        "markdown_inline",
        "printf",
        "python",
        "vim",
        "vimdoc",
      },
    },
  },
}
}

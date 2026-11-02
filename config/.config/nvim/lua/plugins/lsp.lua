return {
  {
    -- Only a source of per-server defaults now; config is plain `vim.lsp.*`.
    "neovim/nvim-lspconfig",
    lazy = false,
    config = function()
      require "cfg.lspconfig"
    end,
  },
}

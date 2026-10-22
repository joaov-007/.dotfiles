return {
  {
    "williamboman/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonUninstall" },
    opts = function()
      return require("cfg.mason").opts
    end,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "mason.nvim" },
    event = "User FilePost",
    config = function()
      require("mason-lspconfig").setup({
        automatic_installation = true,
        ensure_installed = {
          "lua_ls",
          "pyright",
          "bashls",
          "html",
          "emmet_ls",
          "awk_ls",
          "yamlls",
          "jsonls",
          "dockerls",
          "terraformls",
        },
      })
    end,
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason.nvim" },
    event = "VeryLazy",
    opts = {
      ensure_installed = {
        "stylua",
        "prettier",
        "prettierd",
        "black",
        "isort",
        "shfmt",
        "marksman",
        "eslint_d",
        "shellcheck",
        "flake8",
        "delve",
        "debugpy",
        "js-debug-adapter",
        "yaml-language-server",
        "json-lsp",
        "dockerfile-language-server",
        "terraform-ls",
      },
      auto_update = false,
      run_on_start = true,
    },
  },
}

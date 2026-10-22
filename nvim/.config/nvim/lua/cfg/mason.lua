local M = {}

M.opts = {
  ensure_installed = {
    -- LSP
    "lua-language-server",
    "pyright",
    "bash-language-server",
    "html-lsp",
    "emmet-ls",
    "awk-language-server",

    -- Formatters
    "stylua",
    "prettier",
    "prettierd",
    "black",
    "isort",
    "shfmt",
    "marksman",

    -- Linters
    "eslint_d",
    "shellcheck",
    "flake8",
  },
}

return M

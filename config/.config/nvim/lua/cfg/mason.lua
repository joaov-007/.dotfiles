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
    "clangd",

    -- Formatters
    "stylua",
    "prettier",
    "prettierd",
    "black",
    "isort",
    "shfmt",
    "marksman",
    "clang-format",

    -- Linters
    "eslint_d",
    "shellcheck",
    "flake8",
    "golangci-lint",
    "hadolint",
    "cpplint",
    "clang-tidy",

    -- Debuggers
    "delve",
    "debugpy",
    "js-debug-adapter",

    -- Extras
    "yaml-language-server",
    "json-lsp",
    "dockerfile-language-server",
    "terraform-ls",

    -- Tools
    "nvim-lint",
    "bear",
  },
}

return M

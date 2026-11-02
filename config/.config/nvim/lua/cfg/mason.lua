-- Mason package names (not lspconfig server names).
-- Trimmed to what the current config actually formats, lints and completes with.
return {
  ensure_installed = {
    -- Language servers
    "awk-language-server",
    "bash-language-server",
    "clangd",
    "dockerfile-language-server",
    "emmet-ls",
    "eslint-lsp",
    "html-lsp",
    "json-lsp",
    "lua-language-server",
    "marksman",
    "pyright",
    "terraform-ls",
    "typescript-language-server",
    "yaml-language-server",

    -- Formatters
    "black",
    "clang-format",
    "isort",
    "prettierd",
    "shfmt",
    "stylua",

    -- Linters
    "flake8",
    "shellcheck",
  },
}

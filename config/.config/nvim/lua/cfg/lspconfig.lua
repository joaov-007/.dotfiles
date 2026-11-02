-- LSP wiring for Neovim 0.11+ (`vim.lsp.config` / `vim.lsp.enable`).
-- nvim-lspconfig stays only as the source of per-server defaults; no
-- `require("lspconfig").<server>.setup()` calls are needed anymore.
require("nvchad.configs.lspconfig").defaults()

local servers = {
  "awk_ls",
  "bashls",
  "clangd",
  "dockerls",
  "emmet_ls",
  "eslint",
  "html",
  "jsonls",
  "lua_ls",
  "marksman",
  "pyright",
  "terraformls",
  "ts_ls",
  "yamlls",
}

vim.lsp.config("pyright", {
  settings = {
    python = {
      analysis = {
        autoSearchPaths = true,
        typeCheckingMode = "basic",
      },
    },
  },
})

vim.lsp.config("lua_ls", {
  settings = {
    Lua = {
      diagnostics = { globals = { "vim" } },
      workspace = { checkThirdParty = false },
    },
  },
})

vim.lsp.config("clangd", {
  cmd = {
    "clangd",
    "--background-index",
    "--clang-tidy",
    "--header-insertion=iwyu",
    "--all-scopes-completion",
  },
  filetypes = { "c", "cpp", "objc", "objcpp", "h", "hpp", "cuda" },
  root_markers = { "Makefile", "compile_commands.json", "build.json", ".clangd", ".git" },
  settings = {
    clangd = {
      fallbackFlags = {
        "-std=gnu11",
        "-Wall",
        "-Wextra",
        "-Wpedantic",
        "-Werror",
      },
    },
  },
})

vim.lsp.enable(servers)

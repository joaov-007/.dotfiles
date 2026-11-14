-- LSP for Neovim 0.11+.
--
-- nvim-lspconfig stays for its `lsp/<server>.lua` defaults: indexing
-- `vim.lsp.config[name]` resolves them automatically, so this file only
-- declares what differs from upstream. `M.extend()` appends to the resolved
-- config, which keeps the upstream filetypes/root_markers when you only want
-- to add one entry.
local M = {}

local LIST_KEYS = { "filetypes", "root_markers" }

local function append_unique(base, extra)
  local out = vim.list_extend({}, base)
  for _, item in ipairs(extra) do
    if not vim.tbl_contains(out, item) then
      out[#out + 1] = item
    end
  end
  return out
end

--- Merge `opts` into the config for {name}, appending list fields.
---@param name string
---@param opts? vim.lsp.Config
function M.extend(name, opts)
  opts = opts or {}

  local resolved = vim.lsp.config[name]
  if resolved then
    for _, key in ipairs(LIST_KEYS) do
      if type(resolved[key]) == "table" and type(opts[key]) == "table" then
        opts = vim.tbl_extend("force", opts, {
          [key] = append_unique(resolved[key], opts[key]),
        })
      end
    end
  end

  vim.lsp.config(name, opts)
end

-- Capabilities, on_init and NvChad's lua_ls settings.
require("nvchad.configs.lspconfig").defaults()

-- Only overrides live here; cmd/filetypes/root_markers come from lspconfig.
local servers = {
  awk_ls = {},
  bashls = {},
  clangd = {
    cmd = {
      "clangd",
      "--background-index",
      "--clang-tidy",
      "--header-insertion=iwyu",
      "--all-scopes-completion",
    },
    -- Appended to lspconfig's list, which already has .clangd,
    -- compile_commands.json, .clang-format, .clang-tidy and .git.
    root_markers = { "Makefile", "build.json" },
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
  },
  dockerls = {},
  emmet_ls = {},
  eslint = {},
  html = {},
  jsonls = {},
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
      },
    },
  },
  marksman = {},
  pyright = {
    settings = {
      python = {
        analysis = {
          autoSearchPaths = true,
          typeCheckingMode = "basic",
        },
      },
    },
  },
  terraformls = {},
  ts_ls = {},
  yamlls = {},
}

for name, opts in pairs(servers) do
  M.extend(name, opts)
  vim.lsp.enable(name)
end

return M

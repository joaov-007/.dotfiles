require("nvchad.configs.lspconfig").defaults()

local servers = {
  html = {},
  awk_ls = {},
  bashls = {},
  emmet_ls = {},
  ts_ls = {},
  eslint = {},
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
  lua_ls = {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false },
      },
    },
  },
}

-- enable automatically installed servers
for name, opts in pairs(servers) do
  vim.lsp.enable(name)
  vim.lsp.config(name, opts)
end

-- nvim-lint integration for linters UI (loaded after mason installs tools)
vim.api.nvim_create_autocmd("User", {
  pattern = "LazyDone",
  callback = function()
    local ok, lint = pcall(require, "lint")
    if not ok then
      print "nvim-lint not available, skipping lint integration"
      return
    end

    lint.linters_by_ft = {
      python = { "flake8", "pyright" },
      javascript = { "eslint_d" },
      typescript = { "eslint_d" },
      sh = { "shellcheck" },
      markdown = { "marksman" },
    }

    -- auto lint on save (disabled by default, enable via command)
    vim.g.lint_auto = false

    vim.api.nvim_create_user_command("LintToggle", function()
      if vim.g.lint_auto then
        vim.g.lint_auto = false
        lint.linters_by_ft = {}
        print "Linting on save disabled"
      else
        vim.g.lint_auto = true
        print "Linting on save enabled"
      end
    end, {})

    local function lint_on_save()
      if vim.g.lint_auto then
        lint.try_lint()
      end
    end

    vim.api.nvim_create_autocmd("BufWritePost", {
      callback = lint_on_save,
      desc = "Auto lint on save",
    })
  end,
})
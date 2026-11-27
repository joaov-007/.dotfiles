-- nvim-lint integration. Only linters whose executables are actually
-- installed (via Mason or Nix) are wired up here; missing ones are skipped
-- by nvim-lint itself.
local lint = require "lint"

lint.linters_by_ft = {
  python = { "flake8" },
  sh = { "shellcheck" },
  bash = { "shellcheck" },
}

-- Nix: statix/deadnix when installed, plus nix-instantiate (always available
-- on NixOS) for parse errors.
local nix_linters = {}
if vim.fn.executable "statix" == 1 then
  nix_linters[#nix_linters + 1] = "statix"
end
if vim.fn.executable "deadnix" == 1 then
  nix_linters[#nix_linters + 1] = "deadnix"
end
if vim.fn.executable "nix-instantiate" == 1 then
  nix_linters[#nix_linters + 1] = "nix"
end
if #nix_linters > 0 then
  lint.linters_by_ft.nix = nix_linters
end

-- Linting on save is opt-in to avoid noisy diagnostics on every write.
vim.g.lint_auto = false

vim.api.nvim_create_user_command("Lint", function()
  lint.try_lint()
end, { desc = "Run linters on the current buffer" })

vim.api.nvim_create_user_command("LintToggle", function()
  if vim.g.lint_auto then
    vim.g.lint_auto = false
    print "Linting on save disabled"
  else
    vim.g.lint_auto = true
    print "Linting on save enabled"
  end
end, { desc = "Toggle linting on save" })

vim.api.nvim_create_autocmd("BufWritePost", {
  callback = function()
    if vim.g.lint_auto then
      lint.try_lint()
    end
  end,
  desc = "Auto lint on save",
})
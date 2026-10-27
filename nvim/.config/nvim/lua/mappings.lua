require "nvchad.mappings"

-- add yours here

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
-- map("n", "<ESC>", "<CMD> noh <CR>")

-- map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map("n", "<leader>ct", function()
  require("zen-mode").toggle {
    window = {
      width = 0.85, -- width will be 85% of the editor width
    },
  }
end, { desc = "toggle zen mode" })

-- C/C++ specific mappings
map("n", "<leader>ch", function()
  vim.cmd "ClangdSwitchSourceHeader"
end, { desc = "Switch between source and header" })

map("n", "<leader>cH", function()
  vim.cmd "ClangdExplore"
end, { desc = "Clangd explore symbols" })

map("n", "<leader>ca", function()
  vim.lsp.buf.code_action { apply = true, context = { only = { "quickfix", "refactor" } } }
end, { desc = "Code action" })

map("n", "<leader>cd", function()
  vim.diagnostic.open_float()
end, { desc = "Open floating diagnostic" })

map("n", "<leader>cD", function()
  vim.diagnostic.setloclist()
end, { desc = "Set location list with diagnostics" })

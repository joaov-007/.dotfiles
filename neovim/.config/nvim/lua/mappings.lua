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

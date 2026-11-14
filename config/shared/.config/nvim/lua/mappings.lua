local map = vim.keymap.set

-- NvChad's baseline: insert mode, window movement, terminal toggles, etc.
-- Everything below overrides the parts that pointed at telescope/nvim-tree/
-- which-key, plus adds `desc` metadata so mini.clue and the keymap picker can
-- show what a key does without memorizing it.
require "nvchad.mappings"

local function toggle_files()
  local files = require "mini.files"
  if files.close() == nil then
    files.open()
  end
end

local function pick_terms()
  local labels, by_label = {}, {}
  for _, term in pairs(vim.g.nvchad_terms or {}) do
    if term.buf and vim.api.nvim_buf_is_valid(term.buf) then
      local label = string.format("%s (%s)", term.id or vim.api.nvim_buf_get_name(term.buf), term.pos or "?")
      if by_label[label] then
        label = label .. " #" .. term.buf
      end
      labels[#labels + 1] = label
      by_label[label] = term.buf
    end
  end

  if #labels == 0 then
    vim.notify("No terminals", vim.log.levels.INFO)
    return
  end

  require("mini.pick").start {
    source = {
      name = "Terminals",
      items = labels,
      choose = function(item)
        vim.api.nvim_set_current_buf(by_label[item])
      end,
    },
  }
end

-- Core
map("n", ";", ":", { desc = "Command mode" })
map("i", "jk", "<ESC>", { desc = "Leave insert mode" })

-- Keybind discovery
map("n", "<leader>?", "<cmd>NvCheatsheet<CR>", { desc = "Static cheatsheet" })
map("n", "<leader>fk", function()
  require("mini.extra").pickers.keymaps()
end, { desc = "Search keybinds" })
map("n", "<leader>wk", function()
  require("mini.extra").pickers.keymaps()
end, { desc = "Search keybinds" })
map("n", "<leader>wK", function()
  require("mini.extra").pickers.keymaps()
end, { desc = "Search keybinds" })

-- Find
map("n", "<leader>ff", function()
  require("mini.pick").builtin.files()
end, { desc = "Find files" })
map("n", "<leader>fa", function()
  require("mini.files").open(vim.uv.cwd())
end, { desc = "Explore cwd" })
map("n", "<leader>fw", function()
  require("mini.pick").builtin.grep_live()
end, { desc = "Live grep" })
map("n", "<leader>fb", function()
  require("mini.pick").builtin.buffers()
end, { desc = "Find buffers" })
map("n", "<leader>fh", function()
  require("mini.pick").builtin.help()
end, { desc = "Find help" })
map("n", "<leader>fo", function()
  require("mini.extra").pickers.oldfiles()
end, { desc = "Find recent files" })
map("n", "<leader>fz", function()
  require("mini.extra").pickers.buf_lines()
end, { desc = "Find lines in buffer" })
map("n", "<leader>ma", function()
  require("mini.extra").pickers.marks()
end, { desc = "Find marks" })

-- Git
map("n", "<leader>gt", function()
  require("mini.extra").pickers.git_status()
end, { desc = "Git status" })
map("n", "<leader>cm", function()
  require("mini.extra").pickers.git_commits()
end, { desc = "Git commits" })
map("n", "<leader>gd", function()
  require("mini.diff").toggle_overlay()
end, { desc = "Toggle diff overlay" })
map("n", "<leader>gb", function()
  require("mini.git").show_at_cursor()
end, { desc = "Git show at cursor" })
map("n", "<leader>gh", function()
  require("mini.git").show_range_history()
end, { desc = "Git history for range" })

-- Explorer
map("n", "<C-n>", toggle_files, { desc = "Toggle file explorer" })
map("n", "<leader>e", function()
  local path = vim.api.nvim_buf_get_name(0)
  require("mini.files").open(path ~= "" and path or vim.uv.cwd())
end, { desc = "Explore current file" })

-- Terminal picker
map("n", "<leader>pt", pick_terms, { desc = "Pick terminal" })

-- Themes (NvChad's own volt picker; it persists the choice in chadrc)
map("n", "<leader>th", function()
  require("nvchad.themes").open()
end, { desc = "Change theme" })

-- Zen mode replacement
map("n", "<leader>ct", function()
  require("mini.misc").zoom()
end, { desc = "Toggle buffer zoom" })

-- C/C++ helpers
map("n", "<leader>ch", function()
  vim.cmd "ClangdSwitchSourceHeader"
end, { desc = "Switch source/header" })
map("n", "<leader>cH", function()
  vim.cmd "ClangdExplore"
end, { desc = "Clangd explore symbols" })

-- Diagnostics / code actions
map("n", "<leader>ca", function()
  vim.lsp.buf.code_action { apply = true, context = { only = { "quickfix", "refactor" } } }
end, { desc = "Code action" })
map("n", "<leader>cd", vim.diagnostic.open_float, { desc = "Diagnostic float" })
map("n", "<leader>cD", vim.diagnostic.setloclist, { desc = "Diagnostics to loclist" })

-- This file needs to have same structure as nvconfig.lua
-- https://github.com/NvChad/ui/blob/v3.0/lua/nvconfig.lua

---@type ChadrcConfig
local M = {}

M.base46 = {
  theme = "tokyodark",
}

M.nvdash = {
  load_on_startup = true,
  -- Rebuilt for mini.pick/mini.extra; the defaults call Telescope.
  buttons = function()
    return {
      { txt = "  Find File", keys = "ff", cmd = "Pick files" },
      { txt = "  Recent Files", keys = "fo", cmd = "Pick oldfiles" },
      { txt = "  Find Word", keys = "fw", cmd = "Pick grep_live" },
      { txt = "  Themes", keys = "th", cmd = [[lua require('nvchad.themes').open()]] },
      { txt = "  Mappings", keys = "ch", cmd = "NvCheatsheet" },

      { txt = "─", hl = "NvDashFooter", no_gap = true, rep = true },

      {
        txt = function()
          local stats = require("lazy").stats()
          local ms = math.floor(stats.startuptime) .. " ms"
          return "  Loaded " .. stats.loaded .. "/" .. stats.count .. " plugins in " .. ms
        end,
        hl = "NvDashFooter",
        no_gap = true,
        content = "fit",
      },

      { txt = "─", hl = "NvDashFooter", no_gap = true, rep = true },
    }
  end,
}

M.ui = {
  tabufline = {
    lazyload = false,
  },
}
return M

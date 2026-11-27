-- One dependency, many modules. Each `require` below replaces a plugin NvChad
-- used to pull in (and which is disabled in `plugins/init.lua`).
return {
  {
    "echasnovski/mini.nvim",
    version = false,
    lazy = false,
    dependencies = { "nvim-tree/nvim-web-devicons" },
    -- Load before NvChad's UI so the devicons mock is in place when the
    -- tabufline/statusline render for the first time.
    priority = 1000,
    config = function()
      -- Merge nvim-web-devicons' icon set into mini.icons so the combined list
      -- (nerd-font glyphs + web-devicons colors) is what nvim uses everywhere.
      local merged = { extension = {}, file = {}, os = {} }
      local ok, webdevicons = pcall(require, "nvim-web-devicons")
      if ok then
        pcall(webdevicons.setup, {})
        local function convert(data)
          if type(data) ~= "table" or type(data.icon) ~= "string" then return nil end
          return { glyph = data.icon, hl = (type(data.name) == "string") and ("DevIcon" .. data.name) or nil }
        end
        local sources = {
          { getter = webdevicons.get_icons_by_extension, target = merged.extension },
          { getter = webdevicons.get_icons_by_filename, target = merged.file },
          { getter = webdevicons.get_icons_by_operating_system, target = merged.os },
        }
        for _, src in ipairs(sources) do
          local pok, tbl = pcall(src.getter)
          if pok and type(tbl) == "table" then
            for k, v in pairs(tbl) do
              local c = convert(v)
              if c then src.target[tostring(k):lower()] = c end
            end
          end
        end
      end

      local icons = require "mini.icons"
      icons.setup(vim.tbl_deep_extend("force", { style = "glyph" }, merged))
      icons.mock_nvim_web_devicons()
      icons.tweak_lsp_kind()

      -- Editing
      require("mini.ai").setup { n_lines = 500 }
      require("mini.pairs").setup()
      require("mini.surround").setup()
      require("mini.move").setup()
      require("mini.indentscope").setup { symbol = "│" }

      -- Finders and file manager
      require("mini.pick").setup {
        window = { config = { border = "rounded" } },
      }
      require("mini.extra").setup()
      require("mini.files").setup {
        options = { use_as_default_explorer = true },
      }

      -- Git
      require("mini.diff").setup {
        view = {
          signs = { add = "│", change = "│", delete = "󰍵" },
        },
      }
      require("mini.git").setup()

      -- Completion (LSP + snippets through vim.snippet). Keep <C-b>/<C-f>
      -- free for NvChad's insert-mode motions.
      require("mini.completion").setup {
        mappings = { scroll_down = "", scroll_up = "" },
      }

      -- Window zoom, used as the zen-mode replacement
      require("mini.misc").setup()

      -- Keybind discovery: shows descriptions while you type a prefix.
      local clue = require "mini.clue"
      clue.setup {
        triggers = {
          { mode = "n", keys = "<Leader>" },
          { mode = "x", keys = "<Leader>" },
          { mode = "n", keys = "[" },
          { mode = "n", keys = "]" },
          { mode = "n", keys = "g" },
          { mode = "x", keys = "g" },
          { mode = "n", keys = "z" },
          { mode = "x", keys = "z" },
          { mode = "n", keys = "<C-w>" },
          { mode = "i", keys = "<C-x>" },
          { mode = "n", keys = '"' },
          { mode = "x", keys = '"' },
          { mode = "i", keys = "<C-r>" },
          { mode = "c", keys = "<C-r>" },
        },
        clues = {
          clue.gen_clues.square_brackets(),
          clue.gen_clues.builtin_completion(),
          clue.gen_clues.g(),
          clue.gen_clues.marks(),
          clue.gen_clues.registers(),
          clue.gen_clues.windows(),
          clue.gen_clues.z(),
        },
        window = { delay = 250 },
      }
    end,
  },
}

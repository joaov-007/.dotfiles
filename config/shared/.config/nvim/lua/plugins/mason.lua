return {
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUpdate", "MasonUninstall" },
  },
  {
    "WhoIsSethDaniel/mason-tool-installer.nvim",
    dependencies = { "mason.nvim" },
    event = "VeryLazy",
    opts = function()
      return {
        ensure_installed = require("cfg.mason").ensure_installed,
        auto_update = true,
        run_on_start = true,
      }
    end,
  },
}

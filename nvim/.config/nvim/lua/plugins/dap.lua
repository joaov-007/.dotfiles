return {
  {
    "mfussenegger/nvim-dap",
    dependencies = { "rcarriga/nvim-dap-ui", "nvim-neotest/nvim-nio" },
    config = function()
      local dap, dapui = require "dap", require "dapui"
      dapui.setup()
      dap.listeners.after.event_initialized["dapui_config"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui_config"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui_config"] = function() dapui.close() end
    end,
  },
  { "leoluz/nvim-dap-go", ft = "go", dependencies = "mfussenegger/nvim-dap", config = function() require("dap-go").setup() end },
  { "mfussenegger/nvim-dap-python", ft = "python", dependencies = "mfussenegger/nvim-dap", config = function() require("dap-python").setup "python3" end },
  { "theHamsta/nvim-dap-virtual-text", dependencies = "mfussenegger/nvim-dap", config = function() require("nvim-dap-virtual-text").setup() end },
}
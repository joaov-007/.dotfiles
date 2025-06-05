return {
	"stevearc/conform.nvim",
	event = "BufWritePre", -- uncomment for format on save
	cmd = { "ConformInfo" },
	opts = require("configs.conform"),
	init = function()
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}

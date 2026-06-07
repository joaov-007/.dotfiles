local options = {
	formatters_by_ft = {
		lua = { "stylua" },
		python = { "black" },
		javascript = { "prettier" },
		typescript = { "prettier" },
		json = { "prettier" },
		markdown = { "prettier" },
		nix = { "nixfmt" },
	},
	format_on_save = {
		timeout_ms = 5000,
		lsp_fallback = true,
	},
}

return options

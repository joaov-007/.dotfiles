return {
	"WhoIsSethDaniel/mason-tool-installer.nvim",
	dependencies = { "williamboman/mason.nvim" },
	cmd = "MasonToolsInstall",
	opts = {
		ensure_installed = {
			"lua-language-server",
			"pyright",
			"marksman",
			"clangd",
			"rust-analyzer",
			"gopls",
			"typescript-language-server",
			"emmet-language-server",
			"stylua",
			"black",
			"prettier",
			"nixfmt",
		},
		auto_update = true,
		run_on_start = true,
	},
}

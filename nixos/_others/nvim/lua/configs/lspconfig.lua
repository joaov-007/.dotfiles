require("nvchad.configs.lspconfig").defaults()

local servers = {
	"lua_ls", "pyright", "marksman", "clangd",
	"rust_analyzer", "gopls", "ts_ls", "jsonls", "emmet_ls",
}

for _, name in ipairs(servers) do
	local ok, config = pcall(require, "lsp." .. name)
	if ok and config then
		vim.lsp.config[name] = config
	end
end

vim.lsp.enable(servers)

require "nvchad.mappings"

local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")

-- LSP
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "K", vim.lsp.buf.hover, { desc = "Hover documentation" })
map("n", "<leader>vws", vim.lsp.buf.workspace_symbol, { desc = "Workspace symbol" })
map("n", "<leader>vd", vim.diagnostic.open_float, { desc = "Diagnostic float" })
map("n", "<leader>vca", vim.lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>vrr", vim.lsp.buf.references, { desc = "References" })
map("n", "<leader>vrn", vim.lsp.buf.rename, { desc = "Rename" })
map("i", "<C-h>", vim.lsp.buf.signature_help, { desc = "Signature help" })
map("n", "[d", vim.diagnostic.goto_prev, { desc = "Prev diagnostic" })
map("n", "]d", vim.diagnostic.goto_next, { desc = "Next diagnostic" })

-- Formatter
map("n", "<leader>fm", function()
	require("conform").format({ bufnr = 0 })
end, { desc = "Format buffer" })

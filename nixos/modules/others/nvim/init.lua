vim.pack.add({
  'https://github.com/folke/tokyonight.nvim',
})

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.clipboard = 'unnamedplus'
vim.opt.scrolloff = 8
vim.opt.termguicolors = true
vim.opt.signcolumn = 'yes'
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.incsearch = true
vim.opt.hlsearch = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.mouse = 'a'
vim.opt.undofile = true
vim.opt.completeopt = { 'menu', 'menuone', 'noselect' }
vim.opt.shortmess:append({ c = true })
vim.opt.updatetime = 300
vim.g.mapleader = ' '
vim.g.maplocalleader = '\\'

require('tokyonight').setup({
  style = 'night',
})
vim.cmd.colorscheme('tokyonight-night')

vim.lsp.enable({ 'pyright', 'lua_ls', 'nixd', 'marksman' })

vim.lsp.config['lua_ls'] = {
  settings = {
    Lua = { diagnostics = { globals = { 'vim' } } },
  },
}

local function map(mode, lhs, rhs, desc)
  vim.keymap.set(mode, lhs, rhs, { desc = desc, silent = true })
end

map('n', 'K',          vim.lsp.buf.hover,       'LSP: hover')
map('n', 'gd',         vim.lsp.buf.definition,  'LSP: goto def')
map('n', 'gr',         vim.lsp.buf.references,  'LSP: refs')
map('n', '<leader>rn', vim.lsp.buf.rename,      'LSP: rename')
map('n', '<leader>ca', vim.lsp.buf.code_action, 'LSP: code action')
map('n', '<leader>e',  vim.diagnostic.open_float, 'LSP: show diagnostics')
map('n', '[d',         vim.diagnostic.goto_prev,  'LSP: prev diagnostic')
map('n', ']d',         vim.diagnostic.goto_next,  'LSP: next diagnostic')
map('n', '<leader>w',  '<cmd>w<CR>',              'Save file')
map('n', '<leader>q',  '<cmd>q<CR>',              'Close window')
map('n', '<leader>h',  '<cmd>nohlsearch<CR>',     'Clear search highlight')

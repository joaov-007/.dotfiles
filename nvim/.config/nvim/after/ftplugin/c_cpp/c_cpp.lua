-- C/C++ specific settings for nvchad
-- Enable line numbers and relative numbers
vim.o.number = true
vim.o.relativenumber = true

-- Tab settings (Linux kernel style: 8 spaces, no tab expansion)
vim.b.tabstop = 8
vim.b.shiftwidth = 8
vim.b.softtabstop = 8
vim.b.expandtab = false

-- Auto indentation
vim.b.cindent = true
vim.b.cinkeys:remove("0#") -- don't indent # preprocessor lines

-- Disable comment auto-continuation for C comments
vim.b.formatoptions:remove("c")
vim.b.formatoptions:remove("r")
vim.b.formatoptions:remove("o")

-- Set makeprg to use make if available
if vim.fn.executable("make") then
  vim.b.makeprg = "make"
end

-- Set grepprg to use ripgrep
if vim.fn.executable("rg") then
  vim.b.grepprg = "rg --no-heading --grep"
end

-- Disable built-in vim completion for C/C++ (use nvim-cmp or other)
vim.b.completeopt:remove("preview")

-- Kernel-specific: set path to kernel headers if available
-- This is just a placeholder - users should set this to their kernel source
-- vim.b.keywordprg = " man"

-- Add useful comments
print("C/C++ kernel development settings loaded")
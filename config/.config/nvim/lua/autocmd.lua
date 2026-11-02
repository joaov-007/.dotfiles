local autocmd = vim.api.nvim_create_autocmd

-- autocmd("VimEnter", {
--   command = ":silent !kitty @ set-spacing padding=0 margin=0",
-- })
--
-- autocmd("VimLeavePre", {
--   command = ":silent !kitty @ set-spacing padding=20 margin=10",
-- })

autocmd("BufDelete", {
  callback = function()
    local bufs = vim.t.bufs
    if #bufs == 1 and vim.api.nvim_buf_get_name(bufs[1]) == "" then
      vim.cmd "Nvdash"
    end
  end,
})

-- NvChad's statusline reads gitsigns' buffer variables. mini.diff/mini.git
-- expose the same data under their own names, so mirror it here.
autocmd("User", {
  pattern = { "MiniGitUpdated", "MiniDiffUpdated" },
  callback = function(args)
    local buf = (args.data and args.data.buf) or args.buf
    if not vim.api.nvim_buf_is_valid(buf) or vim.b[buf].minigit_summary_string == nil then
      if vim.api.nvim_buf_is_valid(buf) then
        vim.b[buf].gitsigns_head = nil
        vim.b[buf].gitsigns_status_dict = nil
      end
      return
    end

    local ok_git, git = pcall(require, "mini.git")
    local git_data = ok_git and git.get_buf_data(buf) or nil
    local head = git_data and git_data.head_name

    if not head or head == "" then
      vim.b[buf].gitsigns_head = nil
      vim.b[buf].gitsigns_status_dict = nil
      return
    end

    local summary = vim.b[buf].minidiff_summary or {}
    vim.b[buf].gitsigns_head = head
    vim.b[buf].gitsigns_git_status = nil
    vim.b[buf].gitsigns_status_dict = {
      head = head,
      added = summary.add or 0,
      changed = summary.change or 0,
      removed = summary.delete or 0,
    }
  end,
})

-- A flash over the exact text I just yanked, since a yank changes nothing on
-- screen. vim.hl.on_yank leaves deletes, changes and macro replays alone.

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("mivn.yank", { clear = true }),
  desc = "Flash what was just yanked",
  callback = function()
    vim.hl.on_yank({ higroup = "MivnYank" })
  end,
})

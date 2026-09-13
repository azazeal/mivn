-- A flash over what I just yanked.
--
-- Every other edit shows itself. Text appears, text goes away, the line moves
-- under the caret. A yank changes nothing on screen, and it is the one that
-- reaches furthest, since `y` here is the system clipboard and what it took
-- is about to be pasted into another window (lua/mivn/keymaps.lua). So the
-- yanked text gets a tint for a moment and then the window is as it was.
--
-- The exact region and not the line it is on, so `yiw` and `yy` look
-- different and I can see I took the word I meant rather than trusting that
-- I did.
--
-- vim.hl.on_yank does the rest of the deciding, which is why there is nothing
-- to decide here. It draws for a yank alone: `v:event.operator` carries the
-- operator's own letter, and a delete or a change needs no flash because the
-- text going away is the flash. It stays quiet while a macro is replaying, so
-- a macro with a yank in it does not strobe. And its 150ms is over before the
-- hand has finished moving, which is the whole of what the timing has to do.
--
-- The colour is MivnYank, in colors/basalt.lua, along with the reason it is
-- the one it is.

vim.api.nvim_create_autocmd("TextYankPost", {
  group = vim.api.nvim_create_augroup("mivn.yank", { clear = true }),
  desc = "Flash what was just yanked",
  callback = function()
    vim.hl.on_yank({ higroup = "MivnYank" })
  end,
})

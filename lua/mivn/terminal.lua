-- The terminal, as a panel that comes and goes: <leader>` shows and hides one
-- terminal buffer in a split along the bottom. The shell survives hiding,
-- since the toggle only ever touches the window and the buffer stays loaded.
--
-- The key works from Normal mode. Inside the terminal nearly every key goes to
-- the shell, so hiding it from there is Ctrl+\ Ctrl+N first, then the toggle.

local M = {}

local buf -- the one terminal buffer, kept across toggles

--- The window in this tab currently showing a terminal, if any.
local function terminal_window()
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "terminal" then
      return win
    end
  end
end

function M.toggle()
  local win = terminal_window()
  if win then
    vim.api.nvim_win_close(win, false)
    return
  end

  -- A third of the screen, full width along the bottom, under the tree too:
  -- `botright` spells that out rather than leaning on 'splitbelow'.
  vim.cmd(("botright %dsplit"):format(math.floor(vim.o.lines * 0.3)))

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_win_set_buf(0, buf)
  else
    vim.cmd.terminal()
    buf = vim.api.nvim_get_current_buf()

    -- A panel, not a file, so it stays out of the tab bar.
    vim.bo[buf].buflisted = false
  end

  -- Land typing, the way a terminal should open.
  vim.cmd.startinsert()
end

-- When the shell exits, the panel goes with it. Without this, Neovim wipes the
-- dead terminal buffer on the next keypress but leaves its window behind
-- holding an empty one: a dead split and a stray unnamed tab to clean up by
-- hand. Scheduled, because the buffer is still settling while TermClose fires.
vim.api.nvim_create_autocmd("TermClose", {
  group = vim.api.nvim_create_augroup("mivn.terminal", { clear = true }),
  callback = function(ev)
    if ev.buf ~= buf then
      return
    end

    buf = nil
    vim.schedule(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == ev.buf then
          -- pcall for the it-was-the-last-window edge; the tree owns layouts.
          pcall(vim.api.nvim_win_close, win, false)
        end
      end

      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
      end

      -- Deleting the last listed buffer makes Neovim conjure a blank one in
      -- its place, which nothing shows and which sits in the tab bar as a
      -- stray unnamed tab. Unlisting hides it, and is safe where deleting it
      -- could just conjure the next one.
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if
          vim.api.nvim_buf_is_loaded(b)
          and vim.bo[b].buflisted
          and vim.bo[b].buftype == ""
          and not vim.bo[b].modified
          and vim.api.nvim_buf_get_name(b) == ""
          and vim.fn.bufwinid(b) == -1
        then
          vim.bo[b].buflisted = false
        end
      end
    end)
  end,
})

vim.keymap.set("n", "<leader>`", M.toggle, {
  desc = "Show or hide the terminal",
  silent = true,
})

return M

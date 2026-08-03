-- The terminal, as a panel that comes and goes: <leader>` shows and hides one
-- terminal buffer in a split along the bottom. The shell survives hiding,
-- since the toggle only ever touches the window and the buffer stays loaded.
--
-- The key works from Normal mode. Inside the terminal nearly every key goes to
-- the shell, so hiding it from there is Ctrl+\ Ctrl+N first, then the toggle.

local M = {}

local buf -- the one terminal buffer, kept across toggles
local panel_win -- the split the toggle last opened, for the cleanup below

--- The window in this tab showing the panel's own terminal, if any. Matched
--- on the panel's buffer, never on 'buftype': a :terminal split opened by
--- hand is not the panel, and the toggle must not close it.
local function terminal_window()
  if not buf then
    return
  end

  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_buf(win) == buf then
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
  panel_win = vim.api.nvim_get_current_win()

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

-- When the shell exits, the panel goes with it.
--
-- Two shapes, because Neovim closes a cleanly-exited terminal buffer itself
-- before this callback ever runs. When something listed exists to fall back
-- to, it takes the window too and there is nothing left to do. With nothing
-- listed (a session holding only the banner), it leaves the panel's window
-- holding a conjured blank buffer instead, and since the terminal buffer is
-- already gone, that window cannot be found through it: hence panel_win,
-- remembered by the toggle. A shell that exits *nonzero* is the old shape:
-- buffer and window both linger, and the window scan below finds it.
--
-- Scheduled, because the layout is still settling while TermClose fires.
vim.api.nvim_create_autocmd("TermClose", {
  group = vim.api.nvim_create_augroup("mivn.terminal", { clear = true }),
  callback = function(ev)
    if ev.buf ~= buf then
      return
    end

    buf = nil

    local targets = { panel_win }
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_buf(win) == ev.buf then
        targets[#targets + 1] = win
      end
    end

    vim.schedule(function()
      for _, win in ipairs(targets) do
        -- Only a window still holding the dead terminal or a blank orphan is
        -- the panel's leftover; anything else means it was repurposed.
        if win and vim.api.nvim_win_is_valid(win) then
          local b = vim.api.nvim_win_get_buf(win)
          local leftover = vim.bo[b].buftype == "terminal"
            or (vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) == "" and not vim.bo[b].modified)

          if leftover then
            -- pcall for the it-was-the-last-window edge; the tree owns
            -- layouts.
            pcall(vim.api.nvim_win_close, win, false)
          end
        end
      end

      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
      end

      -- Deleting the last listed buffer makes Neovim conjure a blank one in
      -- its place, which nothing shows and which sits in the tab bar as a
      -- stray unnamed tab. Unlisted, not deleted: deleting the last one
      -- could just conjure the next.
      require("mivn.session").reap_blanks("unlist")
    end)
  end,
})

vim.keymap.set("n", "<leader>`", M.toggle, {
  desc = "Show or hide the terminal",
  silent = true,
})

return M

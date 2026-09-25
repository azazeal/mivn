-- The terminal, as a panel that comes and goes: one terminal buffer in a split
-- along the bottom. The shell survives hiding, since the toggle only ever
-- touches the window and the buffer stays loaded.

local M = {}

local buf -- the one terminal buffer, kept across toggles
local panel_win -- the split the toggle last opened, for the cleanup below

--- The window in this tab showing the panel's own terminal, if any.
---
--- NOTE: matched on the panel's buffer, never on 'buftype'. A :terminal split
--- opened by hand is not the panel, and the toggle must not close it.
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

--- Whether the panel is on screen.
function M.is_open()
  return terminal_window() ~= nil
end

--- Show the panel, typing into it, or hide it when it is on screen.
function M.toggle()
  local win = terminal_window()
  if win then
    vim.api.nvim_win_close(win, false)
    return
  end

  -- a third of the screen, full width, under the tree too
  vim.cmd(("botright %dsplit"):format(math.floor(vim.o.lines * 0.3)))
  panel_win = vim.api.nvim_get_current_win()

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_win_set_buf(0, buf)
  else
    vim.cmd.terminal()
    buf = vim.api.nvim_get_current_buf()

    -- a panel, not a file, so it stays out of the tab bar
    vim.bo[buf].buflisted = false
  end

  vim.cmd.startinsert()
end

-- When the shell exits, the panel goes with it. Scheduled, because the layout
-- is still settling while TermClose fires.
--
-- NOTE: there are two shapes to clean up. Neovim deletes a cleanly exited
-- terminal's buffer itself before this runs; with something listed to fall back
-- to, the window goes too, but with nothing listed (only the banner) the window
-- is left holding a new blank buffer, and only panel_win can find it. A shell
-- that exits nonzero leaves both buffer and window, and the window scan below
-- finds it.
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
        -- only the dead terminal or a blank orphan is the panel's; anything
        -- else means the window was reused
        if win and vim.api.nvim_win_is_valid(win) then
          local b = vim.api.nvim_win_get_buf(win)
          local leftover = vim.bo[b].buftype == "terminal"
            or (vim.bo[b].buftype == "" and vim.api.nvim_buf_get_name(b) == "" and not vim.bo[b].modified)

          if leftover then
            -- pcall, since it may be the last window
            pcall(vim.api.nvim_win_close, win, false)
          end
        end
      end

      if vim.api.nvim_buf_is_valid(ev.buf) then
        pcall(vim.api.nvim_buf_delete, ev.buf, { force = true })
      end

      -- deleting the last listed buffer leaves a blank one in the tab bar
      require("mivn.session").reap_blanks("unlist")
    end)
  end,
})

return M

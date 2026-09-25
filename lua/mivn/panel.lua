-- What a panel window has in common: the file tree and the landing buffer are
-- lists to point at, so both hide the cursor and let the highlighted row say
-- where I am. 'guicursor' is global, so the hiding goes through
-- lua/mivn/caret.lua.

local caret = require("mivn.caret")

local M = {}

-- A fully transparent group, so the cursor has nothing to draw. Only a GUI
-- takes this; a terminal draws its own cursor and keeps drawing it.
local GROUP = "MivnCursorHidden"

--- The filetypes whose windows hide the cursor, as a set.
local panels = {}

--- Hide the cursor while a window showing `filetype` is the focused one.
function M.hide_cursor_in(filetype)
  panels[filetype] = true
end

local group = vim.api.nvim_create_augroup("mivn.panel", { clear = true })

-- Worked out again on every arrival rather than paired with a leave, so no
-- closed window or float can leave the cursor hidden. BufEnter too, because
-- the landing buffer arrives in the window I am already in.
--
-- NOTE: the work waits for the next tick because a plugin can stand in another
-- window for a moment and come back without a second arrival. Opening the tree
-- without focus does that, so the last event says NvimTree while I am in the
-- file; read at the event, the cursor stays hidden for the rest of the session.
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWinEnter" }, {
  group = group,
  callback = function()
    vim.schedule(function()
      if panels[vim.bo.filetype] then
        return caret.override("panel", GROUP)
      end

      caret.drop("panel")
    end)
  end,
})

return M

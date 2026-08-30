-- What a panel window has in common: the file tree and the landing buffer are
-- lists to point at, so both hide the cursor and let the highlighted row say
-- where I am.
--
-- It is a module of its own because the panels are, not because of the caret.
-- 'guicursor' is global and lua/mivn/caret.lua owns it, so hiding is an
-- override asked for by name here rather than the option being swapped out and
-- put back, which is what used to leak when Select mode wanted it too.

local caret = require("mivn.caret")

local M = {}

-- The trick: 'guicursor' takes a highlight group per mode, and a fully
-- transparent group leaves the cursor with no pixels to draw. The group is
-- defined in colors/basalt.lua.
--
-- Only a GUI draws its own cursor, so this reaches Neovide and not a terminal,
-- where the cursor belongs to the terminal and keeps being drawn.
local GROUP = "MivnCursorHidden"

--- The filetypes whose windows hide the cursor, as a set.
local panels = {}

--- Hide the cursor while a window showing `filetype` is the focused one.
function M.hide_cursor_in(filetype)
  panels[filetype] = true
end

local group = vim.api.nvim_create_augroup("mivn.panel", { clear = true })

-- Recomputed on every arrival rather than paired enter/leave autocmds per
-- panel, so the state follows from where the cursor actually is and no closed
-- window or float can leave it hidden somewhere that never asked for it.
--
-- BufEnter is needed beside WinEnter because the landing buffer arrives by
-- being put into the window I am already in, which is not a window change.
--
-- WARN: the work is put off to the next tick because these events also fire
-- while a plugin is standing in another window for a moment. Opening the tree
-- without giving it focus is that case: it enters its own window, fills it,
-- and puts me back without a second arrival, so the last event says NvimTree
-- while I am sitting in the file. Read at the event, the caret stays hidden
-- for the rest of the session; read a tick later, every one of them agrees on
-- the window I am actually in. Both calls are no-ops when nothing changed, so
-- a burst of events costs one write to the option at most.
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

-- What a panel window has in common: the file tree and the landing buffer are
-- lists to point at, so both hide the cursor and let the highlighted row say
-- where I am.
--
-- It is a module of its own because 'guicursor' is global. Hiding the cursor
-- in one window means swapping the whole option on the way in and putting it
-- back on the way out, and two callers doing that separately would race over
-- which of them saved the real value. One autocmd owns the state instead.

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

--- The 'guicursor' to put back, and nil when it is not swapped out. Doubles as
--- the "is it hidden right now" flag, so the two can never disagree.
local saved = nil

local function hide()
  if saved then
    return
  end

  saved = vim.o.guicursor

  -- Appended rather than replacing: a later entry wins for the modes it names,
  -- so this recolors every cursor shape without redefining any of them.
  vim.o.guicursor = saved .. ",a:" .. GROUP .. "/" .. GROUP
end

local function show()
  if not saved then
    return
  end

  vim.o.guicursor = saved
  saved = nil
end

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
vim.api.nvim_create_autocmd({ "WinEnter", "BufEnter", "BufWinEnter" }, {
  group = group,
  callback = function()
    if panels[vim.bo.filetype] then
      return hide()
    end

    show()
  end,
})

return M

-- Ctrl and a vertical arrow carries the line, or the selected lines, up or
-- down. The chord is the one I rebind to in every editor that lets me, and
-- xileh has it too. It is free: without a mapping Ctrl+Up scrolled by a
-- line, which Ctrl+E and Ctrl+Y already do.
--
-- Built on :move because `dd`/`p` would overwrite the unnamed register on
-- every press, and `p` is the clipboard now besides; :move touches no
-- register at all. The customary reindent (`==`, and mini.move's default) is
-- deliberately absent: it trusts the filetype's indent, and Rust's flattens a
-- `.method()` chain line to column zero. The move is exact and indentation
-- stays mine.
--
-- One function for all four modes, so that the lines move the same way
-- whatever I was doing when I pressed the key. Normal and Insert take the
-- caret's line; Visual and Select take the lines the selection touches and
-- keep it, so holding the key walks the block through the file. The keys
-- are lua/mivn/keymaps.lua's.

local selection = require("mivn.selection")

local M = {}

--- Move lines `first` through `last` by `by`, which is -1 or 1, unless that
--- would push them past either end of the buffer. Says whether they moved.
local function move(first, last, by)
  local count = vim.api.nvim_buf_line_count(0)
  if (by < 0 and first + by < 1) or (by > 0 and last + by > count) then
    return false
  end

  -- :move puts the lines *below* the address it is given.
  local below = by < 0 and first + by - 1 or last + by
  vim.cmd(("silent %d,%dmove %d"):format(first, last, below))

  return true
end

local function step(by)
  return function()
    local mode = vim.fn.mode()

    if not selection.holds(mode) then
      -- In Insert the completion menu is the land mine: while it is open the
      -- text is locked (:move dies with E565), and the menu is open a lot as
      -- I type. Closed through the API rather than a fed Ctrl+E, which
      -- would only land after the move.
      if vim.fn.pumvisible() == 1 then
        vim.api.nvim_select_popupmenu_item(-1, false, true, {})
      end

      local row = vim.api.nvim_win_get_cursor(0)[1]
      move(row, row, by)
      return
    end

    local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")
    if not move(math.min(anchor[2], caret[2]), math.max(anchor[2], caret[2]), by) then
      return
    end

    vim.cmd("normal! " .. vim.keycode("<Esc>"))
    selection.restore(mode, { anchor[2] + by, anchor[3] - 1 }, { caret[2] + by, caret[3] - 1 })
  end
end

M.up = step(-1)
M.down = step(1)

return M

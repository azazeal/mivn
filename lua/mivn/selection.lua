-- Putting a selection back after the text under it changed: the same shape,
-- the same two ends, and Select still Select.

local M = {}

--- The Visual command that opens a selection of the same shape as `mode`.
--- Select's three come back through Visual and are switched over at the end.
local SHAPE = {
  v = "v",
  V = "V",
  ["\22"] = "\22",
  s = "v",
  S = "V",
  ["\19"] = "\22",
}

--- Whether `mode`, as mode() spells it, has something picked out.
function M.holds(mode)
  return SHAPE[mode] ~= nil
end

--- Whether `mode` is one of Select's three, where a printable key replaces
--- what is picked out.
function M.selecting(mode)
  return mode == "s" or mode == "S" or mode == "\19"
end

--- Pick out `anchor` to `caret` again, in `mode`'s shape. Both are {row, col}
--- with the column 0-based, and the cursor is left on `caret`.
---
--- NOTE: not `gv`. It restores the marks the selection left, and with
--- 'selection' exclusive the end mark sits one column short of the caret, so
--- every press would pull the caret one column left. A shift also moves the
--- text out from under the columns the marks remember.
function M.restore(mode, anchor, caret)
  vim.api.nvim_win_set_cursor(0, anchor)
  vim.cmd("normal! " .. SHAPE[mode])
  vim.api.nvim_win_set_cursor(0, caret)

  if M.selecting(mode) then
    vim.cmd("normal! " .. vim.keycode("<C-g>"))
  end
end

return M

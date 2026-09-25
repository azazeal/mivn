-- Moving the caret's line, or the lines a selection touches, up or down,
-- keeping the selection, the same way in all four modes. It is :move, so no
-- register is touched, and nothing is reindented after it, since a filetype's
-- indent can be wrong: Rust's puts a `.method()` chain line at column zero.

local selection = require("mivn.selection")

local M = {}

--- Move lines `first` to `last` by `by` (-1 or 1), unless that would push them
--- past an end of the buffer. Returns whether they moved.
local function move(first, last, by)
  local count = vim.api.nvim_buf_line_count(0)
  if (by < 0 and first + by < 1) or (by > 0 and last + by > count) then
    return false
  end

  -- :move puts the lines below the address it is given
  local below = by < 0 and first + by - 1 or last + by
  vim.cmd(("silent %d,%dmove %d"):format(first, last, below))

  return true
end

local function step(by)
  return function()
    local mode = vim.fn.mode()

    if not selection.holds(mode) then
      -- NOTE: while the completion menu is open the text is locked and :move
      -- fails with E565. The menu is closed through the API, since a fed Ctrl+E
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

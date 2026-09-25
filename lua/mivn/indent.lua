-- Tab and Shift+Tab over a selection, as in Zed: indent or dedent every line it
-- touches and keep the same text selected, so holding the key walks the block
-- across. `>` and `<` stay Vim's operators, and Normal mode gets neither key,
-- since Tab there is Ctrl+I, the jumplist.
--
-- The shift is Vim's own `>` rather than an edit by hand, so a count means
-- levels and `.` repeats it, and with 'selection' exclusive a selection that
-- ends at column 1 of a line leaves that line alone.

local selection = require("mivn.selection")

local M = {}

--- The leading whitespace of `row`, in bytes. The selection's ends move by how
--- much this changed rather than by 'shiftwidth', since 'shiftround' and a
--- dedent that runs out of whitespace both change the step.
local function indent_of(row)
  return #(vim.fn.getline(row):match("^%s*"))
end

--- Indent (`step` 1) or dedent (`step` -1) the selection, keeping it.
local function shift(step)
  return function()
    -- NOTE: a snippet placeholder is a Select-mode selection, and these keys
    -- replace Neovim's own snippet jump on Tab and Shift+Tab, so the jump is
    -- answered before the indent.
    if vim.snippet.active({ direction = step }) then
      vim.snippet.jump(step)
      return
    end

    local mode = vim.fn.mode()

    -- `>` where no edits are taken (the tree, the terminal, the banner) is E21
    if not selection.holds(mode) or not vim.bo.modifiable then
      return
    end

    local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")
    local before = { [anchor[2]] = indent_of(anchor[2]), [caret[2]] = indent_of(caret[2]) }

    local over = selection.selecting(mode) and vim.keycode("<C-g>") or ""
    vim.cmd("normal! " .. over .. vim.v.count1 .. (step > 0 and ">" or "<"))

    -- each end moves by what its own line's indent changed by
    local function moved(pos)
      local delta = indent_of(pos[2]) - before[pos[2]]
      return { pos[2], math.max(pos[3] - 1 + delta, 0) }
    end

    selection.restore(mode, moved(anchor), moved(caret))
  end
end

M.indent = shift(1)
M.dedent = shift(-1)

--- Shift+Tab while typing: back to the previous snippet placeholder, standing
--- in for Neovim's own Shift+Tab, or one step of indent off the line (Vim's own
--- Ctrl+D).
function M.dedent_line()
  if vim.snippet.active({ direction = -1 }) then
    return "<Cmd>lua vim.snippet.jump(-1)<CR>"
  end

  return "<C-d>"
end

return M

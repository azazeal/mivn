-- Tab and Shift+Tab over what is picked out, which is Zed's pair.
--
-- Tab indents every line the selection touches and Shift+Tab dedents them,
-- and either way the same text stays picked out, so holding the key walks the
-- block across the screen. Zed's `tab` and `backtab` do exactly this, and the
-- keys are the ones my hands come with.
--
-- `>` and `<` are left alone. They are Vim's operators, they end the selection
-- the way every operator does, and nothing here changes that: one CUA key and
-- one Vim key, each honest about what it does.
--
-- Normal mode gets neither. Tab is Ctrl+I in a terminal, which is the
-- jumplist, and DEFAULTS.md is on the hook for that key staying Vim's. So
-- Zed's "backtab dedents the line with nothing selected" is not mirrored
-- there; `<<` is one keystroke and already does it.
--
-- WARN: a snippet placeholder is a Select-mode selection, so the jump has to
-- be answered before the indent. Neovim maps Tab and Shift+Tab in Insert and
-- Select to vim.snippet.jump for as long as a snippet is live, and taking the
-- keys here takes those with them. Zed reads the same way round: its snippet
-- bindings carry `!showing_completions`, so the menu wins, then the
-- placeholder, then the indent.
--
-- The operator is Vim's own `>` rather than an edit made by hand, which is
-- what keeps a count meaning levels and `.` repeating the shift afterwards.
-- Both measured. It also gets one rule right for free: with 'selection'
-- exclusive, a selection ending at column 1 of a line leaves that line alone,
-- which is the rule Zed writes out as "a selection ending at column 0 does
-- not indent that line".

local M = {}

--- The Visual command that re-opens a selection of the same shape, keyed by
--- the mode it was made in. Select's three shapes come back through Visual,
--- which is where the operator has to run anyway.
local SHAPE = {
  v = "v",
  V = "V",
  ["\22"] = "\22",
  s = "v",
  S = "V",
  ["\19"] = "\22",
}

--- Whether the mode is one of Select's three, where a printable key replaces
--- what is picked out and an operator therefore cannot be typed at it.
local function selecting(mode)
  return mode == "s" or mode == "S" or mode == "\19"
end

--- The leading whitespace of `row`, in bytes, which is what an indent moves.
--- Measured rather than assumed: 'shiftround' and a dedent that runs out of
--- whitespace both make the step something other than 'shiftwidth'.
local function indent_of(row)
  return #(vim.fn.getline(row):match("^%s*"))
end

--- Indent (`step` 1) or dedent (`step` -1) the selection, keeping it.
local function shift(step)
  return function()
    -- The placeholder first: `step` is the direction vim.snippet wants.
    if vim.snippet.active({ direction = step }) then
      vim.snippet.jump(step)
      return
    end

    local mode = vim.fn.mode()
    local shape = SHAPE[mode]

    -- Nothing picked out, or a buffer that takes no edits: the tree, the
    -- terminal and the banner can all hold a selection, and `>` on one of
    -- them is E21 rather than a no-op.
    if not shape or not vim.bo.modifiable then
      return
    end

    local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")
    local before = { [anchor[2]] = indent_of(anchor[2]), [caret[2]] = indent_of(caret[2]) }

    local over = selecting(mode) and vim.keycode("<C-g>") or ""
    vim.cmd("normal! " .. over .. vim.v.count1 .. (step > 0 and ">" or "<"))

    -- WARN: `gv` is not enough. It restores the columns the selection had,
    -- and the shift has moved the text out from under them, so after one
    -- press the highlight sits on the wrong characters. Each end moves by
    -- what its own line's indent actually changed by.
    local function moved(pos)
      local delta = indent_of(pos[2]) - before[pos[2]]
      return { pos[2], math.max(pos[3] - 1 + delta, 0) }
    end

    vim.api.nvim_win_set_cursor(0, moved(anchor))
    vim.cmd("normal! " .. shape)
    vim.api.nvim_win_set_cursor(0, moved(caret))

    if selecting(mode) then
      vim.cmd("normal! " .. vim.keycode("<C-g>"))
    end
  end
end

M.indent = shift(1)
M.dedent = shift(-1)

--- Shift+Tab while typing: back to the previous placeholder, or one step of
--- indent off the line.
---
--- `<C-d>` is Vim's own, and it is what Zed's backtab does with nothing
--- picked out. Tab needs no partner to this: a tab is what the key types.
function M.dedent_line()
  if vim.snippet.active({ direction = -1 }) then
    return "<Cmd>lua vim.snippet.jump(-1)<CR>"
  end

  return "<C-d>"
end

return M

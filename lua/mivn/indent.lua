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

local selection = require("mivn.selection")

local M = {}

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

    -- Nothing picked out, or a buffer that takes no edits: the tree, the
    -- terminal and the banner can all hold a selection, and `>` on one of
    -- them is E21 rather than a no-op.
    if not selection.holds(mode) or not vim.bo.modifiable then
      return
    end

    local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")
    local before = { [anchor[2]] = indent_of(anchor[2]), [caret[2]] = indent_of(caret[2]) }

    local over = selection.selecting(mode) and vim.keycode("<C-g>") or ""
    vim.cmd("normal! " .. over .. vim.v.count1 .. (step > 0 and ">" or "<"))

    -- Each end moves by what its own line's indent changed by.
    local function moved(pos)
      local delta = indent_of(pos[2]) - before[pos[2]]
      return { pos[2], math.max(pos[3] - 1 + delta, 0) }
    end

    selection.restore(mode, moved(anchor), moved(caret))
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

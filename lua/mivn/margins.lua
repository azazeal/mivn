-- How long lines are shown: the width markers, and the wrap toggle.
--
-- The markers: prose wraps hard at 80, code carries a soft 100 and a hard
-- 120. Instead of colorcolumn's full stripe, the single character one column
-- past each limit is colored, escalating from green to red, so only a line
-- that crosses a limit shows anything.
--
-- What gets counted is the text, at the width it displays: a tab counts as
-- the columns it takes, and an inlay hint, which is not text, counts for
-- nothing. That rules out matchadd and `\%81v`, the obvious way to write
-- this: `\%v` is the *screen* column, so a line carrying 12 columns of hints
-- had its 69th character marked as if it were the 81st. The width comes from
-- the buffer text instead, and the marks are drawn per line as the window
-- redraws.

local MARKS = {
  { column = 81, group = "MivnMargin80" },
  { column = 101, group = "MivnMargin100" },
  { column = 121, group = "MivnMargin120" },
}

local ns = vim.api.nvim_create_namespace("mivn.margins")

--- The length in bytes of the UTF-8 character `byte` starts.
local function char_length(byte)
  if byte < 0xc0 then
    return 1
  elseif byte < 0xe0 then
    return 2
  elseif byte < 0xf0 then
    return 3
  end

  return 4
end

--- Mark the character standing on each limit `line` crosses.
---
--- One pass over the line, stopping at the last limit or the end of the line,
--- whichever comes first. ASCII and tabs are measured here because they are
--- the whole of most lines; anything else is handed to strdisplaywidth, which
--- knows about wide characters and about the `^X` spelling of a control one.
local function mark(bufnr, row, line, tabstop)
  local index = 1 -- where the character starts, in bytes
  local column = 1 -- and the display column it starts on

  for _, limit in ipairs(MARKS) do
    while index <= #line do
      local byte = line:byte(index)
      local length, width = 1, 1

      if byte == 0x09 then
        width = tabstop - (column - 1) % tabstop
      elseif byte < 0x20 or byte >= 0x7f then
        length = char_length(byte)
        width = vim.fn.strdisplaywidth(line:sub(index, index + length - 1))
      end

      if column + width > limit.column then
        vim.api.nvim_buf_set_extmark(bufnr, ns, row, index - 1, {
          end_col = index - 1 + length,
          hl_group = limit.group,
          ephemeral = true,
        })
        break
      end

      index = index + length
      column = column + width
    end

    if index > #line then
      return -- the line stops short of this limit, so of every later one too
    end
  end
end

-- Only ordinary file buffers get markers; the tree, the terminal and the
-- banner have no width budget.
vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, bufnr)
    return vim.bo[bufnr].buftype == ""
  end,

  on_line = function(_, _, bufnr, row)
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, true)[1]

    -- Bytes are never fewer than the columns they display, tabs and control
    -- characters aside, so this is what most lines cost.
    if #line < MARKS[1].column and not line:find("%c") then
      return
    end

    mark(bufnr, row, line, vim.bo[bufnr].tabstop)
  end,
})

-- Long lines run off the right edge ('wrap' is off in init.lua); this brings
-- them back for the window I am in. Window-local, so a prose buffer can wrap
-- while the code beside it does not.
vim.keymap.set("n", "<leader>w", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle wrapping of long lines" })

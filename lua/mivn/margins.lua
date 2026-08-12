-- How long lines are shown: the width markers, the wrap toggle, and the
-- column the `|` motion goes to.
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

      -- A codepoint that adds no width to what it follows, a combining
      -- accent or an emoji joiner, is part of this character: measured
      -- alone it reads 1 and the count drifts. Absorb codepoints for as
      -- long as the character's width stays put; multibyte ones only, an
      -- ASCII follower is always its own character. Not after a tab, whose
      -- width above is positional and would confuse the remeasurement.
      while byte ~= 0x09 and index + length <= #line and line:byte(index + length) >= 0x80 do
        local extra = char_length(line:byte(index + length))
        local grown = vim.fn.strdisplaywidth(line:sub(index, index + length + extra - 1))

        if grown > width then
          break
        end

        width = grown
        length = length + extra
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
    -- Not strict: a row can vanish mid-redraw, and one error here would
    -- disable this provider for good.
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

    -- Bytes are never fewer than the columns they display, tabs and control
    -- characters aside, so this is what most lines cost.
    if not line or (#line < MARKS[1].column and not line:find("%c")) then
      return
    end

    mark(bufnr, row, line, vim.bo[bufnr].tabstop)
  end,
})

-- `{count}|` goes to a column, and Vim counts that column in screen cells: a
-- tab is its full display width and an inlay hint, which is not even text,
-- counts too, so the col a compiler prints in file:line:col landed short of
-- its target. Respelled to the character column: a tab is one, a hint is
-- nothing, and the status line (lua/mivn/statusline.lua) reads the same
-- number this takes. `g|` keeps the screen-cell meaning.
vim.keymap.set({ "n", "x", "o" }, "|", function()
  vim.fn.setcursorcharpos(vim.fn.line("."), vim.v.count1)
end, { desc = "To the {count}'th character of the line" })

-- Long lines run off the right edge ('wrap' is off in init.lua); this brings
-- them back for the window I am in. Window-local, so a prose buffer can wrap
-- while the code beside it does not.
vim.keymap.set("n", "<leader>w", function()
  vim.wo.wrap = not vim.wo.wrap
end, { desc = "Toggle wrapping of long lines" })

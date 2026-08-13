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

--- The length in bytes of the character starting at `index`, as it is drawn:
--- a multibyte sequence counts whole only when every continuation byte is in
--- place, and a torn one is drawn, and so counted, one byte at a time.
---
--- This check is also what keeps a NUL out of every substring handed to
--- strdisplaywidth: a NUL is never a valid continuation byte, so a sequence
--- reaching one is cut at length 1, before the NUL.
local function sequence_length(line, index)
  local length = char_length(line:byte(index))

  for i = index + 1, index + length - 1 do
    local byte = line:byte(i)

    if not byte or byte < 0x80 or byte >= 0xc0 then
      return 1
    end
  end

  return length
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
  local nul_width -- what this window draws a NUL at, measured on first use

  for _, limit in ipairs(MARKS) do
    while index <= #line do
      local byte = line:byte(index)
      local length, width = 1, 1

      if byte == 0x09 then
        width = tabstop - (column - 1) % tabstop
      elseif byte == 0x00 then
        -- The one byte strdisplaywidth cannot be asked about: a Lua string
        -- carrying a NUL crosses into Vim as a Blob, and the call throws
        -- E976 on every redraw the line is visible for (the crash any
        -- binary file used to cause here). Vim stores a NUL in text as a
        -- newline, and the newline character draws at the same width: ^@
        -- and ^J plain, <00> and <0a> under 'display' uhex. So the newline
        -- is measured in its stead.
        nul_width = nul_width or vim.fn.strdisplaywidth("\n")
        width = nul_width
      elseif byte < 0x20 or byte >= 0x7f then
        length = sequence_length(line, index)
        width = vim.fn.strdisplaywidth(line:sub(index, index + length - 1))
      end

      -- A codepoint that adds no width to what it follows, a combining
      -- accent or an emoji joiner, is part of this character: measured
      -- alone it reads 1 and the count drifts. Absorb codepoints for as
      -- long as the character's width stays put; multibyte ones only, an
      -- ASCII follower is always its own character. Not after a tab, whose
      -- width above is positional, nor a NUL, which no measured substring
      -- may contain.
      while byte ~= 0x09 and byte ~= 0x00 and index + length <= #line and line:byte(index + length) >= 0x80 do
        local extra = sequence_length(line, index + length)
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
    -- Not strict: a row can vanish mid-redraw, and an error here is not
    -- raised once. Nothing turns the provider off, so the line repeats it on
    -- every redraw and the message area fills up.
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]

    if not line then
      return
    end

    if #line < MARKS[1].column then
      -- Printable ASCII draws one column per byte, so a short line of it
      -- cannot reach the first limit; this is what most lines cost. The
      -- escapes: a tab or a control character can draw wider than a column
      -- each (mark measures those), and a byte 0x80 and up can stand alone
      -- and draw as <xx>, four columns, so those lines get one whole-line
      -- measurement instead. Safe, because a line without a %c match
      -- carries no NUL.
      if not line:find("[%c\128-\255]") then
        return
      end

      if not line:find("%c") and vim.fn.strdisplaywidth(line) < MARKS[1].column then
        return
      end
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

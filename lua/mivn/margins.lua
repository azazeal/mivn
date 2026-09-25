-- How long lines are shown: the width markers, the wrap toggle, and the
-- column the `|` motion goes to.
--
-- The markers: prose wraps hard at 80, code carries a soft 100 and a hard
-- 120. Instead of colorcolumn's full stripe, the one character past each limit
-- is colored, green to red, so only a line that crosses a limit shows anything.
--
-- NOTE: the width is counted from the buffer text, not with matchadd and
-- `\%81v`. `\%v` is the screen column, where an inlay hint counts too, so a
-- line carrying hints would be marked early. Here a tab counts as the columns
-- it takes and a hint counts for nothing.

local M = {}

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
--- NOTE: this is also what keeps a NUL out of every substring handed to
--- strdisplaywidth. A NUL is never a continuation byte, so a sequence reaching
--- one is cut at length 1, before the NUL.
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

--- Mark the character standing on each limit `line` crosses, in one pass that
--- stops at the last limit or the end of the line. ASCII and tabs, the whole
--- of most lines, are measured here; anything else goes to strdisplaywidth,
--- which knows wide characters and the `^X` spelling of a control one.
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
        -- NOTE: a NUL is never handed to strdisplaywidth. A Lua string
        -- carrying one crosses into Vim as a Blob, and the call throws E976
        -- on every redraw. Vim stores a NUL in text as a newline and the two
        -- draw at the same width (^@ and ^J, or <00> and <0a> under
        -- 'display' uhex), so the newline is measured instead.
        nul_width = nul_width or vim.fn.strdisplaywidth("\n")
        width = nul_width
      elseif byte < 0x20 or byte >= 0x7f then
        length = sequence_length(line, index)
        width = vim.fn.strdisplaywidth(line:sub(index, index + length - 1))
      end

      -- NOTE: a codepoint that adds no width to what it follows (a combining
      -- accent, an emoji joiner) is part of this character, since measured
      -- alone it reads 1 and the count drifts. Only multibyte followers are
      -- taken in, and never after a tab, whose width is positional, or a NUL,
      -- which strdisplaywidth must not see.
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

-- Only file buffers get markers; the tree, the terminal and the banner have
-- no width to keep to.
vim.api.nvim_set_decoration_provider(ns, {
  on_win = function(_, _, bufnr)
    return vim.bo[bufnr].buftype == ""
  end,

  -- The end is exclusive, so an end of `(row, 0)` leaves that row out. A range
  -- that starts partway into a line still gets the whole line measured; an
  -- ephemeral mark outside what is drawn costs nothing.
  on_range = function(_, _, bufnr, first, _, last, last_col)
    if last_col == 0 then
      last = last - 1
    end

    -- NOTE: not strict, because a row can vanish mid-redraw, and an error
    -- here is raised again on every redraw since nothing turns the provider
    -- off.
    local lines = vim.api.nvim_buf_get_lines(bufnr, first, last + 1, false)
    local tabstop = vim.bo[bufnr].tabstop

    for offset, line in ipairs(lines) do
      local row = first + offset - 1

      -- NOTE: most lines cannot reach the first limit and are skipped here.
      -- Only ASCII is counted in bytes; anything else is measured whole, since
      -- a Greek letter is two bytes and a stray byte draws as <xx>. The %c
      -- test is also what keeps a NUL away from strdisplaywidth.
      local ascii = not line:find("[\128-\255]")
      local short = not line:find("%c")
        and (ascii and #line < MARKS[1].column or not ascii and vim.fn.strdisplaywidth(line) < MARKS[1].column)

      if not short then
        mark(bufnr, row, line, tabstop)
      end
    end
  end,
})

-- Markdown reflows to 80 on `gq`, where the ftplugin's 'textwidth' of 0 would
-- take the window's width. The ftplugin's `t` in 'formatoptions' goes, so
-- nothing wraps as I type: that breaks only the line under me and leaves the
-- paragraph around it ragged.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("mivn.margins.prose", { clear = true }),
  pattern = "markdown",
  desc = "Reflow markdown to 80 columns, on gq rather than while typing",
  callback = function()
    vim.bo.textwidth = MARKS[1].column - 1
    vim.opt_local.formatoptions:remove("t")
  end,
})

--- The keys ------------------------------------------------------------------

--- To the {count}'th character of the line. Vim's `|` counts screen cells, a
--- tab's full width and inlay hints too; here a tab is one and a hint is
--- nothing, so the col in a compiler's file:line:col lands where it says, and
--- the status line shows the same number.
function M.to_char_column()
  vim.fn.setcursorcharpos(vim.fn.line("."), vim.v.count1)
end

--- Wrap long lines in this window, or stop, and say which: a window with no
--- line long enough to wrap looks the same either way.
function M.toggle_wrap()
  vim.wo.wrap = not vim.wo.wrap

  vim.notify(("Wrap: %s"):format(vim.wo.wrap and "on" or "off"))
end

return M

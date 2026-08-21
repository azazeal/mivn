-- Moving by a word, and by a piece of one.
--
-- The shape is Zed's, because it is the one my hands have: going right lands
-- on the end of a word, going left on the start of one. That asymmetry is not
-- an oversight in either editor. Travel in a direction should stop at the far
-- side of what it crossed, and the far side of a word is its end going right
-- and its start going left.
--
-- Vim has both as `e` and `b`, so the word half of this file is only the keys.
-- What it has none of is the subword, the piece of an identifier a camel hump
-- or an underscore marks off, so that half is here.
--
-- The WORD, Vim's whitespace-delimited kind, is bound to nothing: it crosses
-- `foo::bar(baz(r, g, b))` in one press, which is never the distance I mean.
-- `W`, `B`, `E` and `gE` still exist, unbound and unremoved, because they are
-- Vim's grammar and this file takes nothing away from it.

local M = {}

--- Which kind of character this is, for deciding where one subword stops and
--- the next begins. Everything not named here is punctuation, which is its
--- own kind: `foo::bar` is three pieces, not one.
local function kind(char)
  if char == "" then
    return nil
  elseif char:match("%s") then
    return "space"
  elseif char == "_" then
    return "under"
  elseif char:match("%u") then
    return "upper"
  elseif char:match("[%l%d]") then
    return "lower"
  end

  return "punct"
end

--- Where the subwords of `line` are, as {first, last} byte columns, 1-based
--- and inclusive.
---
--- Underscores and whitespace are separators and belong to no piece, so
--- `parse_http_url` is three. A hump starts a piece, so `parseHTTPUrl` is
--- `parse`, `HTTP` and `Url`: a run of capitals is one piece until the last
--- of them turns out to be the head of a word, which is only knowable from
--- the letter after it.
local function subwords(line)
  local spans = {}
  local i, n = 1, #line

  while i <= n do
    local here = kind(line:sub(i, i))

    if here == "space" or here == "under" then
      i = i + 1
    elseif here == "punct" then
      -- One piece per run of punctuation, so `::` is a stop and `(` after it
      -- is another.
      local first = i
      while i <= n and kind(line:sub(i, i)) == "punct" do
        i = i + 1
      end
      spans[#spans + 1] = { first, i - 1 }
    else
      local first = i

      -- A single capital may open a piece; a run of them is a piece of its
      -- own unless the last one heads the next.
      if here == "upper" then
        while i <= n and kind(line:sub(i, i)) == "upper" do
          i = i + 1
        end

        if i - first > 1 and i <= n and kind(line:sub(i, i)) == "lower" then
          i = i - 1
        end
      end

      if i == first or kind(line:sub(i, i)) == "lower" then
        while i <= n and kind(line:sub(i, i)) == "lower" do
          i = i + 1
        end
      end

      spans[#spans + 1] = { first, i - 1 }
    end
  end

  return spans
end

--- The buffer position a subword move lands on, or nil when there is none
--- left in that direction.
---
--- `forward` asks for the end of the next piece and its opposite for the
--- start of the previous one, the same asymmetry the word keys have. Lines
--- are crossed, since a piece running out is no reason to stop.
---
--- The end is the column *after* the piece's last character, not that
--- character. 'selection' is exclusive here, so the cursor marks a boundary
--- between characters rather than a character, and a selection back to the
--- start of the piece then holds the piece and nothing else. 'virtualedit'
--- is what lets that boundary exist at the end of a line.
local function target(forward)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local last = vim.api.nvim_buf_line_count(0)
  local from = col + 1 -- nvim_win_get_cursor is 0-based on the column

  while row >= 1 and row <= last do
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    local spans = subwords(line)

    if forward then
      for _, span in ipairs(spans) do
        if span[2] >= from then
          return { row, span[2] }
        end
      end

      row, from = row + 1, 0
    else
      for i = #spans, 1, -1 do
        if spans[i][1] < from then
          return { row, spans[i][1] - 1 }
        end
      end

      row = row - 1
      from = math.huge
    end
  end

  return nil
end

--- Move to the end of the next subword, or the start of the previous one.
---
--- Not an operator-pending motion: `d` and one of these would need a real
--- motion rather than a cursor put somewhere, and the shifted keys already
--- cover selecting a piece and doing something to it.
function M.subword(forward)
  return function()
    local to = target(forward)
    if to then
      vim.api.nvim_win_set_cursor(0, to)
    end
  end
end

--- Open a Visual selection and then move, for a shifted key pressed with
--- nothing selected yet.
function M.select_subword(forward)
  local move = M.subword(forward)

  return function()
    vim.cmd("normal! v")
    move()
  end
end

return M

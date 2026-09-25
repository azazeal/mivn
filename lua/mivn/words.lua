-- Moving by a piece of text: a word, a subword, or a WORD. The arrows run on
-- this, and so do `e`, `E`, `ge` and `gE`; `w`, `b`, `W` and `B` stay Vim's,
-- since they already land on the first character of a piece.
--
-- The end of a piece is the boundary after its last character, since the caret
-- here sits between two characters. Going right an arrow stops past the end of
-- a piece and going left on its start. The WORD serves `E` and `gE` only.
--
-- Every size is parsed here rather than borrowed from Vim's keys. `e` goes to
-- the end of the next word when the caret is already at the end of one, which
-- here is every time a word ends against the next: on `foo (bar) baz`, from the
-- end of `bar`, one press would cross both `)` and `baz`. `ge` skips the same
-- way backwards.

local M = {}

--- The graphemes of `line`, the smallest thing a piece may start or end at.
---
--- NOTE: graphemes and not bytes, since the grapheme is what the cursor moves
--- by; a split by byte cuts `👩‍💻` apart and lands the caret inside it. A line
--- with no byte above 127 skips Vim and takes one grapheme per byte, because
--- split() costs milliseconds on a very long line and this runs on every press.
local function graphemes(line)
  if not line:find("[\128-\255]") then
    local out = {}
    for i = 1, #line do
      out[i] = line:sub(i, i)
    end

    return out
  end

  return vim.fn.split(line, "\\zs")
end

--- The kind of grapheme `char` is, for where one piece stops and the next
--- begins: "space", "punct", "upper", "lower", or "under" (`_` and the
--- punctuation in `joined`). Past ASCII the answer is Vim's charclass(), and an
--- uncased script's kind is its class number, so a run stops where the script
--- changes: `私は日本語を` is five pieces.
local function kind(char, joined)
  if char == "" then
    return nil
  elseif char == "_" or joined[char] then
    return "under"
  elseif #char == 1 then
    if char:match("%s") then
      return "space"
    elseif char:match("%u") then
      return "upper"
    elseif char:match("[%l%d]") then
      return "lower"
    end

    return "punct"
  end

  local class = vim.fn.charclass(char)

  if class == 0 then
    return "space"
  elseif class == 1 then
    return "punct"
  elseif class == 2 then
    -- a cased letter, so `ΚαλήΜέρα` splits at its hump like `FooBar`
    return vim.fn.tolower(char) ~= char and "upper" or "lower"
  end

  return class
end

--- The ASCII punctuation 'iskeyword' makes part of a word (`-` in CSS, `$` in
--- PHP), which then acts like `_`, so `e` agrees with Vim's `w` on where a word
--- ends. A set per value of the option, since it is read on every press.
local joining = {}

local function joins()
  local option = vim.bo.iskeyword
  local set = joining[option]

  if not set then
    set = {}
    for byte = 33, 126 do
      local char = string.char(byte)
      if not char:match("[%w_]") and vim.fn.charclass(char) == 2 then
        set[char] = true
      end
    end

    joining[option] = set
  end

  return set
end

--- Where the pieces of `line` are, as {first, last} byte columns, 1-based and
--- inclusive. `size` is "word", "subword" or "WORD".
---
--- A word is Vim's: letters, digits and underscores run together and each run
--- of punctuation is a piece, so `foo_bar(baz` is three. A WORD ends only at
--- whitespace, so the same text is one. A subword splits a word further:
--- underscores separate like whitespace, so `parse_http_url` is three, and a
--- hump starts a piece, so `parseHTTPUrl` is `parse`, `HTTP` and `Url`.
local function spans_of(line, size)
  local units = graphemes(line)
  local n = #units

  -- the byte each grapheme starts at, plus one past the last
  local column = {}
  local byte = 1
  for i = 1, n do
    column[i] = byte
    byte = byte + #units[i]
  end
  column[n + 1] = byte

  -- nil past the last, which every comparison below reads as "not that kind"
  local joined = joins()
  local kinds = {}
  for i = 1, n do
    kinds[i] = kind(units[i], joined)
  end

  local spans = {}
  local i = 1

  while i <= n do
    local here = kinds[i]

    if here == "space" or (size == "subword" and here == "under") then
      i = i + 1
    elseif size == "WORD" then
      local first = i
      while i <= n and kinds[i] ~= "space" do
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    elseif here == "punct" then
      local first = i
      while i <= n and kinds[i] == "punct" do
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    elseif type(here) == "number" then
      -- an uncased script (kanji, kana, emoji), so no hump to split on
      local first = i
      while i <= n and kinds[i] == here do
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    elseif size == "word" then
      local first = i
      while i <= n do
        local what = kinds[i]
        if what ~= "upper" and what ~= "lower" and what ~= "under" then
          break
        end
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    else
      local first = i

      -- a run of capitals is a piece of its own, unless its last heads the next
      if here == "upper" then
        while i <= n and kinds[i] == "upper" do
          i = i + 1
        end

        if i - first > 1 and i <= n and kinds[i] == "lower" then
          i = i - 1
        end
      end

      if i == first or kinds[i] == "lower" then
        while i <= n and kinds[i] == "lower" do
          i = i + 1
        end
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    end
  end

  return spans
end

--- The 0-based column a move to `span` stops at: past its last character when
--- `ending`, else on its first. The column past the end of a line exists only
--- because of 'virtualedit'.
local function edge(span, ending)
  return ending and span[2] or span[1] - 1
end

--- The cursor position a move lands on, or nil when there is nothing left that
--- way. `forward` and `ending` are the two axes of Vim's `w`, `e`, `b` and
--- `ge`. A move crosses lines.
local function target(forward, ending, size)
  local row, col = unpack(vim.api.nvim_win_get_cursor(0))
  local last = vim.api.nvim_buf_line_count(0)
  local from = col

  while row >= 1 and row <= last do
    local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
    local spans = spans_of(line, size)

    if forward then
      for _, span in ipairs(spans) do
        local at = edge(span, ending)
        if at > from then
          return { row, at }
        end
      end

      -- below every column, so the next line's column zero counts
      row, from = row + 1, -1
    else
      for i = #spans, 1, -1 do
        local at = edge(spans[i], ending)
        if at < from then
          return { row, at }
        end
      end

      row, from = row - 1, math.huge
    end
  end

  return nil
end

--- Take `count` steps, stopping early where the direction runs out.
local function step(forward, ending, size, count)
  for _ = 1, count do
    local to = target(forward, ending, size)
    if not to then
      return
    end

    vim.api.nvim_win_set_cursor(0, to)
  end
end

--- A function that moves to one side of a neighboring piece: past the end of
--- the next, or to the start or past the end of the previous; a count repeats
--- it. Not for Operator-pending, where Vim's own inclusive keys cover the same
--- text.
function M.move(forward, ending, size)
  return function()
    step(forward, ending, size, vim.v.count1)
  end
end

--- Like M.move(), but opens a Visual selection first, for a shifted key pressed
--- with nothing selected yet.
---
--- NOTE: the count is read before `normal! v`, which clears it.
function M.select(forward, ending, size)
  return function()
    local count = vim.v.count1

    vim.cmd("normal! v")
    step(forward, ending, size, count)
  end
end

return M

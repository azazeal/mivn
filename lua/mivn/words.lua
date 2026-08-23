-- Moving by a piece of text: a word, a piece of one, or a WORD. The arrows
-- run on this and so do `e`, `E`, `ge` and `gE`. `w`, `b` and `W`, `B` are
-- Vim's and stay exactly as they ship, because they already land where I
-- want, on the first character of a piece.
--
-- The end of a piece is one place, and it is the boundary *after* its last
-- character rather than that character. That is the whole point of this file
-- and the reason the end keys are remapped onto it. 'selection' is exclusive
-- and the cursor is drawn as a bar, so the caret marks a spot between two
-- characters; stopping on the last letter of a word puts it one place short
-- of where the word ends, and a recorded macro then means something other
-- than what I pressed it for.
--
-- Vim's own four end-and-start keys are the grid this follows: a direction,
-- and which side of a piece to stop at. `w` is forward to a start, `e`
-- forward to an end, `b` back to a start, `ge` back to an end. Three of the
-- four are asked for here, since forward-to-a-start is `w` and untouched.
--
-- The arrows want only one of them. Going right lands past the end of a word
-- and going left on the start of one, which is Zed's shape and the one my
-- hands have. That asymmetry is not an oversight in either editor: travel in
-- a direction should stop at the far side of what it crossed, and the far
-- side of a word is its end going right and its start going left.
--
-- Every size is parsed here rather than borrowed from Vim's keys, and the
-- reason is a hole that borrowing leaves. `e` moves to the end of the *next*
-- word when the cursor already sits at the end of one, which in this model is
-- every time a word ends against the next: on `foo (bar) baz` the caret was
-- already on `)` and `)` had therefore already ended, so one press crossed
-- both `)` and `baz`. Measured, and the reason this file grew. `ge` skips the
-- same way in the other direction.
--
-- The WORD is here for `E` and `gE` and reaches no arrow. It crosses
-- `foo::bar(baz(r, g, b))` in one press, which is never the distance I mean
-- from an arrow.
--
-- The unit throughout is the grapheme, not the byte, because the grapheme is
-- what the cursor moves by: a byte parser cuts `👩‍💻` into three pieces and
-- puts the caret inside one of them. Classifying is Vim's job for the same
-- reason, since it knows 'iskeyword' and the Unicode classes. Before this
-- the parser read bytes and `café` was `caf` and `é`, and `abcαβγ` broke at
-- the Greek.

local M = {}

--- The graphemes of `line`, which is what the cursor moves by and therefore
--- the smallest thing a piece may start or end at. Splitting by byte would
--- cut `👩‍💻` into three and land the caret inside it.
---
--- A line with no byte above 127 is one grapheme per byte, and taking that
--- path rather than asking Vim matters: `split()` costs milliseconds on a
--- very long line, and this runs on every press of the key.
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

--- Which kind a grapheme is, for deciding where one piece stops and the next
--- begins. Everything not named here is punctuation, which is its own kind:
--- `foo::bar` is three pieces, not one.
---
--- ASCII is matched here and everything else is Vim's answer, because Vim
--- knows 'iskeyword' and the Unicode classes and I do not: `καλημέρα` is one
--- word, `«` is punctuation, and `naïve` does not break at the `ï`.
---
--- Outside the cased letters the kind *is* Vim's class number, one per
--- script, and pieces run only with their own. That is what makes the keys
--- work on a language that writes without spaces: `私は日本語を` is five
--- pieces because kanji and hiragana keep changing over, and Vim has no
--- better answer than that either without a dictionary.
local function kind(char)
  if char == "" then
    return nil
  elseif char == "_" then
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
    -- A letter, where case exists and a hump means something, so `ΚαλήΜέρα`
    -- splits under Alt and an arrow the way `FooBar` does.
    return vim.fn.tolower(char) ~= char and "upper" or "lower"
  end

  return class
end

--- Where the pieces of `line` are, as {first, last} byte columns, 1-based and
--- inclusive.
---
--- `size` is "word", "subword" or "WORD". A word is Vim's own kind: letters,
--- digits and underscores run together and punctuation is its own piece, so
--- `foo_bar(baz` is three. A WORD is Vim's other kind, whitespace-delimited,
--- so the same text is one.
---
--- A subword splits a word further. Underscores join whitespace as separators
--- belonging to no piece, so `parse_http_url` is three, and a hump starts a
--- piece, so `parseHTTPUrl` is `parse`, `HTTP` and `Url`: a run of capitals
--- is one piece until the last of them turns out to be the head of a word,
--- which is only knowable from the letter after it.
local function spans_of(line, size)
  local units = graphemes(line)
  local n = #units

  -- Where each grapheme starts, plus one past the last, so that the span
  -- ending before grapheme `i` ends at byte `column[i] - 1`.
  local column = {}
  local byte = 1
  for i = 1, n do
    column[i] = byte
    byte = byte + #units[i]
  end
  column[n + 1] = byte

  local spans = {}
  local i = 1

  while i <= n do
    local here = kind(units[i])

    if here == "space" or (size == "subword" and here == "under") then
      i = i + 1
    elseif size == "WORD" then
      -- Nothing but whitespace ends a WORD, so punctuation joins whatever it
      -- touches and `foo::bar(baz)` is one piece.
      local first = i
      while i <= n and kind(units[i]) ~= "space" do
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    elseif here == "punct" then
      -- One piece per run of punctuation, so `::` is a stop and `(` after it
      -- is another.
      local first = i
      while i <= n and kind(units[i]) == "punct" do
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    elseif type(here) == "number" then
      -- A script of its own: kanji, hiragana, katakana, an emoji. There is
      -- no case in any of them and so no hump to split on, which is why
      -- neither size cuts one of these further.
      local first = i
      while i <= n and kind(units[i]) == here do
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    elseif size == "word" then
      -- Everything a keyword is made of, in one run.
      local first = i
      while i <= n do
        local what = kind(units[i])
        if what ~= "upper" and what ~= "lower" and what ~= "under" then
          break
        end
        i = i + 1
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    else
      local first = i

      -- A single capital may open a piece; a run of them is a piece of its
      -- own unless the last one heads the next.
      if here == "upper" then
        while i <= n and kind(units[i]) == "upper" do
          i = i + 1
        end

        if i - first > 1 and i <= n and kind(units[i]) == "lower" then
          i = i - 1
        end
      end

      if i == first or kind(units[i]) == "lower" then
        while i <= n and kind(units[i]) == "lower" do
          i = i + 1
        end
      end

      spans[#spans + 1] = { column[first], column[i] - 1 }
    end
  end

  return spans
end

--- Which column a piece stops at, 0-based and always a boundary between two
--- characters: the column *after* its last character, or the column of its
--- first.
---
--- 'selection' is exclusive here, so the cursor marks a boundary rather than
--- a character, and a selection from one of these back to another holds the
--- pieces between them and nothing else. 'virtualedit' is what lets the
--- boundary after the last character of a line exist at all.
local function edge(span, ending)
  return ending and span[2] or span[1] - 1
end

--- The buffer position a move lands on, or nil when there is none left in
--- that direction.
---
--- `forward` picks the direction and `ending` which side of a piece to stop
--- at, the two axes Vim's own `w`, `e`, `b` and `ge` are made of. Lines are
--- crossed, since a piece running out is no reason to stop.
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

      -- Below every boundary the next line can offer, column zero included.
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

--- Move to one side of a neighboring piece: past the end of the next one, to
--- the start of the previous one, or past the end of the previous one.
---
--- A count repeats the step, the way it does for the keys these stand in for:
--- `3` and one of them crosses three pieces.
---
--- Not an operator-pending motion: `d` and one of these would need a real
--- motion rather than a cursor put somewhere. After an operator the keys fall
--- back to Vim's own, which are inclusive and cover the same text.
function M.move(forward, ending, size)
  return function()
    step(forward, ending, size, vim.v.count1)
  end
end

--- Open a Visual selection and then move, for a shifted key pressed with
--- nothing selected yet.
---
--- The count is read before the selection opens, since `normal!` clears it.
function M.select(forward, ending, size)
  return function()
    local count = vim.v.count1

    vim.cmd("normal! v")
    step(forward, ending, size, count)
  end
end

return M

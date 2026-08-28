-- Where else the text I have picked out shows up.
--
-- While a selection is up, every other copy of it in the window gets a quiet
-- tint. No caret and no selection state, so the marks say "here too" and
-- nothing more. This is Zed's, and it is the thing I kept reaching for that
-- Neovim has no default for.
--
-- What counts as a copy is the selected bytes exactly, case and all. Not a
-- word and not a pattern, so picking out `for` also marks the middle of
-- `before`. Half a word is usually what I select when I want to see where
-- else it is, and a word-bounded rule finds nothing for those.
--
-- Charwise Visual on one line, and nothing else. A selection over several
-- lines is a block I am about to move rather than a phrase I am looking for,
-- and in Select mode the next letter I type replaces what is picked out, so
-- reading the file is not what I am doing there.
--
-- Only the lines the window is showing are searched. Zed spends a 100ms
-- debounce and a second pass over the whole file at this point, and neither
-- buys anything here: a mark on a line nobody can see is not drawn.
--
-- WARN: the marks are laid down as the selection changes, not drawn on the
-- way past. A decoration provider is the cheaper shape and is what
-- lua/mivn/margins.lua uses, but it cannot answer this question: Neovim asks
-- a provider only about the lines it is already repainting, and extending a
-- selection repaints the line the caret is on and nothing else. Measured on
-- screen: the copies on the caret's line showed up and every other line kept
-- what it had been drawn with before the selection existed. What a mark
-- depends on is what decides the shape. The width markers depend on their
-- own line and nothing else, so a provider suits them; these depend on a
-- selection somewhere else in the window, so they do not.

local ns = vim.api.nvim_create_namespace("mivn.occurrences")

--- The buffer the marks are in, so that dropping them finds the buffer that
--- got them rather than whichever one is current by the time it happens.
local marked = nil

--- Take the marks down.
local function clear()
  if marked and vim.api.nvim_buf_is_valid(marked) then
    vim.api.nvim_buf_clear_namespace(marked, ns, 0, -1)
  end

  marked = nil
end

--- The selection: the text picked out, the row it sits on, and the byte span
--- `[from, to)` it covers there. Nil unless it is one this marks.
---
--- The span's length comes from the text and not from the two columns,
--- because 'selection' is what decides whether the end column is in or out.
--- getregion() already knows; this does not have to.
local function selected()
  if vim.fn.mode() ~= "v" then
    return nil
  end

  local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")

  -- One line, and something on it. A selection that has not opened yet is
  -- not one: 'selection' is exclusive here, so an anchor sitting on the
  -- caret picks out nothing, and getregion() hands back the character under
  -- it regardless (`:h getregion-notes`).
  if anchor[2] ~= caret[2] or anchor[3] == caret[3] then
    return nil
  end

  local text = vim.fn.getregion(anchor, caret, { type = "v" })[1]

  -- Whitespace alone would mark every indent in the window, which is noise
  -- and never the question being asked.
  if not text or text:find("^%s*$") then
    return nil
  end

  local from = math.min(anchor[3], caret[3]) - 1

  return { text = text, row = anchor[2] - 1, from = from, to = from + #text }
end

--- Mark every copy of `selection` on `row` of `bufnr`, given the row's text.
local function mark(bufnr, row, line, selection)
  local index = 1

  while true do
    local start, stop = line:find(selection.text, index, true)

    if not start then
      return
    end

    -- The selection is not another copy of itself, and neither is a match
    -- that runs into it: with `aa` picked out of `aaaa`, the one starting at
    -- the line's first byte is half of what is already highlighted.
    if row ~= selection.row or stop <= selection.from or start - 1 >= selection.to then
      vim.api.nvim_buf_set_extmark(bufnr, ns, row, start - 1, {
        end_col = stop,
        hl_group = "MivnOccurrence",
      })
    end

    index = stop + 1
  end
end

--- Put the marks where they belong for whatever is selected now.
local function refresh()
  clear()

  local selection = selected()

  if not selection then
    return
  end

  local bufnr = vim.api.nvim_get_current_buf()

  -- Only a file is read for repeats. The tree, the terminal and the banner
  -- hold something else, and a selection in one of them is on its way to
  -- being copied rather than looked up.
  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local top, bottom = vim.fn.line("w0"), vim.fn.line("w$")
  local lines = vim.api.nvim_buf_get_lines(bufnr, top - 1, bottom, false)

  for offset, line in ipairs(lines) do
    mark(bufnr, top - 2 + offset, line, selection)
  end

  marked = bufnr
end

vim.api.nvim_create_autocmd({ "CursorMoved", "ModeChanged", "WinScrolled" }, {
  group = vim.api.nvim_create_augroup("mivn.occurrences", { clear = true }),
  desc = "Mark the other copies of what is selected",
  callback = refresh,
})

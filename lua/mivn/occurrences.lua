-- Where else the text I have picked out shows up. While a charwise selection
-- on one line is up, in Visual or Select, every other copy of it on the lines
-- the window shows gets a quiet tint. A copy is the selected bytes exactly,
-- case and all, and not a word, so picking out `for` also marks `before`.
--
-- NOTE: the marks are laid down as the selection changes, not drawn by a
-- decoration provider as the window redraws, the way lua/mivn/margins.lua
-- does it. Neovim asks a provider only about the lines it is repainting, and
-- extending a selection repaints the caret's line alone, so every other line
-- would keep what it had before the selection.

local ns = vim.api.nvim_create_namespace("mivn.occurrences")

--- The buffer holding the marks, so clearing them does not depend on which
--- buffer is current by then.
local marked = nil

local function clear()
  if marked and vim.api.nvim_buf_is_valid(marked) then
    vim.api.nvim_buf_clear_namespace(marked, ns, 0, -1)
  end

  marked = nil
end

--- The selection: its text, its row and the byte span `[from, to)` it covers
--- there, or nil unless it is one to mark. The span's length comes from the
--- text and not from the columns, since 'selection' decides whether the end
--- column is in.
local function selected()
  local mode = vim.fn.mode()

  if mode ~= "v" and mode ~= "s" then
    return nil
  end

  local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")

  -- one line, and not empty: with the anchor on the caret getregion() still
  -- returns the character under it (`:h getregion-notes`)
  if anchor[2] ~= caret[2] or anchor[3] == caret[3] then
    return nil
  end

  -- NOTE: getregion() raises E964 on a column past the end of the line rather
  -- than clamping it, and a position can be out of date for the moment a mode
  -- is changing under it, so both columns are checked first.
  local line = vim.fn.getline(anchor[2])

  if anchor[3] > #line + 1 or caret[3] > #line + 1 then
    return nil
  end

  local text = vim.fn.getregion(anchor, caret, { type = "v" })[1]

  -- whitespace alone would mark every indent in the window
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

    -- not the selection itself, nor a match that overlaps it (`aa` in `aaaa`)
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

  local bufnr = vim.api.nvim_get_current_buf()

  -- files only: in the tree, the terminal or the banner a selection is there
  -- to be copied, not looked up
  if vim.bo[bufnr].buftype ~= "" then
    return
  end

  local selection = selected()

  if not selection then
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

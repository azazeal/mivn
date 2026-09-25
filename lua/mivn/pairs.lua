-- Auto-closing pairs, through mini.pairs with its defaults, and wrapping a
-- selection in a pair, which mini.pairs has no notion of. Enter is not claimed
-- here: complete.lua's <CR> calls MiniPairs.cr() on its newline path.
--
-- Over a selection mini.pairs would replace the text with an empty pair.
-- Instead, as with Zed's `use_auto_surround`, an opening character typed over a
-- Select-mode selection wraps it and keeps it selected, so a second key wraps
-- again; a closing character still replaces. Select mode only, since in Visual
-- `"`, `'` and the backtick are Vim's register and mark keys.
local MiniPairs = require("mini.pairs")

MiniPairs.setup()

--- The keys that wrap a selection and what they wrap it with, sorted by key:
--- every opening character in mini.pairs' own table, quotes included, and none
--- of its closing ones.
---
--- @return { key: string, open: string, close: string }[]
local function surrounds()
  local found = {}

  for key, spec in pairs(MiniPairs.config.mappings) do
    if spec.action ~= "close" and vim.fn.strchars(spec.pair) == 2 then
      found[#found + 1] = {
        key = key,
        open = vim.fn.strcharpart(spec.pair, 0, 1),
        close = vim.fn.strcharpart(spec.pair, 1, 1),
      }
    end
  end

  table.sort(found, function(a, b)
    return a.key < b.key
  end)

  return found
end

--- Run `key` now, as if typed.
---
--- NOTE: :normal and not nvim_feedkeys(). The keys have to run between the
--- cursor moves in surround(), which takes feedkeys' "x" flag, and "x" also
--- runs whatever I have typed ahead, so a letter typed right after the quote
--- would land inside the wrap. :normal leaves the typeahead alone.
local function press(key)
  vim.api.nvim_command("normal! " .. vim.keycode(key))
end

--- The selection's two ends, zero-based as the API counts them, and whether the
--- cursor holds the start; nil when there is nothing to wrap.
local function region()
  -- charwise only, which is all the shifted keys ever open
  if vim.fn.mode() ~= "s" then
    return nil
  end

  local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")

  local from, to = anchor, caret
  local backwards = caret[2] < anchor[2] or (caret[2] == anchor[2] and caret[3] < anchor[3])
  if backwards then
    from, to = caret, anchor
  end

  -- 'selection' is exclusive, so `to` is already one past the last character
  local at = {
    srow = from[2] - 1,
    scol = from[3] - 1,
    erow = to[2] - 1,
    ecol = to[3] - 1,
    backwards = backwards,
  }

  if at.srow == at.erow and at.scol == at.ecol then
    return nil
  end

  return at
end

--- Wrap the selection in `open` and `close` and select the same text again, so
--- extending it carries on and a second key wraps again. Meant for a
--- Select-mode mapping on `open`.
---
--- A wrap is an undo step of its own, since a change made from outside Insert
--- closes the block my typing had open. After Esc, though, the first `u` takes
--- an empty block and the second takes the wrap.
local function surround(open, close)
  local at = region()

  -- NOTE: with nothing to wrap, the key goes back unmapped, since mapped it
  -- would come straight back here. That costs mini.pairs' auto-close, but only
  -- on an empty or linewise selection, which typing never makes.
  if not at then
    vim.api.nvim_feedkeys(open, "ni", false)
    return
  end

  local srow, scol = at.srow, at.scol
  local erow, ecol = at.erow, at.ecol
  local backwards = at.backwards

  -- the closing half first, so the opening one cannot move where it goes
  vim.api.nvim_buf_set_text(0, erow, ecol, erow, ecol, { close })
  vim.api.nvim_buf_set_text(0, srow, scol, srow, scol, { open })

  scol = scol + #open
  if erow == srow then
    ecol = ecol + #open
  end

  -- NOTE: only the cursor's end of a selection can be placed directly, since
  -- Neovim's setpos() does not take "v". `o` swaps which end the cursor holds,
  -- so each end is placed while the cursor is on it, and Ctrl+G either side
  -- goes to Visual and back, because `o` in Select would type over the
  -- selection. The end I was holding stays the one I hold.
  local held = backwards and { erow + 1, ecol } or { srow + 1, scol }
  local moving = backwards and { srow + 1, scol } or { erow + 1, ecol }

  press("<C-g>")

  press("o")
  vim.api.nvim_win_set_cursor(0, held)

  press("o")
  vim.api.nvim_win_set_cursor(0, moving)

  press("<C-g>")
end

return {
  surrounds = surrounds,
  surround = surround,
}

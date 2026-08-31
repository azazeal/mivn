-- Auto-closing pairs: `(` inserts `()` with the cursor between them, typing
-- the closing character walks over the one already there, and Backspace inside
-- an empty pair deletes both halves. Defaults untouched.
--
-- Enter is deliberately not claimed here: complete.lua owns the Insert-mode
-- <CR> mapping and calls MiniPairs.cr() on its newline path. The plugin maps
-- <CR> itself only when nothing else has.
--
-- The other half of this file is wrapping, which mini.pairs has no notion of.
-- It is an Insert-mode plugin, so with a selection open the pair it inserts
-- lands where the selection was and the text is gone: pick out `hello`, type
-- `"`, and the line reads `""`. Measured, and worse than the plain Select-mode
-- answer it replaces, which was at least a single quote.
--
-- What happens instead is Zed's `use_auto_surround`: an opening character
-- typed over a selection wraps it and leaves it picked out, so a second key
-- wraps again. A closing character still replaces, which is Zed's rule too.
--
-- Select mode only. In Visual `"` names a register and `'` and a backtick are
-- mark motions, Vim's own grammar for the keys pressed from Normal, and that
-- is the line this configuration already draws between the two selection
-- modes.
local MiniPairs = require("mini.pairs")

MiniPairs.setup()

--- The characters that wrap and what they wrap with, one entry per key, in a
--- fixed order. Read out of mini.pairs' own table so the two can never
--- disagree about what a pair is: everything it opens with, and the quotes,
--- which open and close on the same key. Its closing characters are left out,
--- so `)` over a selection still replaces.
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

--- Runs `key` as if it were typed, without disturbing anything already in the
--- typeahead, which is what tells this apart from nvim_feedkeys.
local function press(key)
  vim.api.nvim_command("normal! " .. vim.keycode(key))
end

--- What a wrap would go around: the two ends of the selection as the API
--- counts them, from zero, and which of them the cursor is holding. Nil when
--- there is nothing to wrap.
local function region()
  -- Charwise Select alone. Linewise and blockwise are not reachable while
  -- typing, since what the shifted keys open is always charwise
  -- (keymaps.lua), and an empty selection is not a selection.
  if vim.fn.mode() ~= "s" then
    return nil
  end

  local anchor, caret = vim.fn.getpos("v"), vim.fn.getpos(".")

  local from, to = anchor, caret
  local backwards = caret[2] < anchor[2] or (caret[2] == anchor[2] and caret[3] < anchor[3])
  if backwards then
    from, to = caret, anchor
  end

  -- 'selection' is exclusive (init.lua), so `to` is already where the closing
  -- half goes: one past the last character picked out.
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

--- Wraps what is picked out in `open` and `close`, then picks the same text
--- out again so that extending it carries on and wrapping it twice is two
--- keystrokes. Meant for a Select-mode mapping on `open`.
local function surround(open, close)
  local at = region()

  -- Nothing to wrap: the key goes back the way it came, and unmapped, which
  -- is what keeps it from arriving here a second time and looping. That costs
  -- mini.pairs' auto-close on those keystrokes, so a quote typed with nothing
  -- picked out is one quote and not a pair. Both halves of the trade are in a
  -- corner: an empty selection, or a linewise one, which is two keys from
  -- Normal and unreachable from typing.
  if not at then
    vim.api.nvim_feedkeys(open, "ni", false)
    return
  end

  local srow, scol = at.srow, at.scol
  local erow, ecol = at.erow, at.ecol
  local backwards = at.backwards

  -- A wrap comes off on its own `u`, and the typing around it stays. That is
  -- Vim's doing rather than mine: a buffer changed from outside Insert closes
  -- the undo block that the typing had open, so nothing here has to ask for
  -- it. Measured 2026-08-31, and the cost is a spent keypress: leaving the
  -- wrap with Esc opens an empty block on the way back into Insert, so the
  -- first `u` after that has nothing to take off and the second one takes the
  -- wrap.
  --
  -- The closing half first, so that inserting the opening one cannot move the
  -- place it goes.
  vim.api.nvim_buf_set_text(0, erow, ecol, erow, ecol, { close })
  vim.api.nvim_buf_set_text(0, srow, scol, srow, scol, { open })

  scol = scol + #open
  if erow == srow then
    ecol = ecol + #open
  end

  -- Then the same text is picked out again, with the end I was holding still
  -- the end I hold, so extending it carries on where it left off and another
  -- wrap is one key.
  --
  -- Only one of the two ends can be placed directly: the cursor is an API
  -- call and the far end is not, since `setpos()` takes "v" in Vim 9 and not
  -- in Neovim (measured on 0.12.4). `o` is what reaches it, swapping which
  -- end the cursor holds, so each end is placed while the cursor is on it.
  -- Ctrl+G either side of that is Select to Visual and back, because `o` in
  -- Select is a letter that would replace everything picked out.
  --
  -- WARN: :normal and not nvim_feedkeys. These keys have to run *between* the
  -- cursor moves, which takes feedkeys' "x", and "x" also runs whatever I
  -- have already typed ahead: typing the quote and the next letter quickly
  -- enough put that letter in the middle of the wrap. Measured. :normal runs
  -- its own keys and leaves the typeahead alone.
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
